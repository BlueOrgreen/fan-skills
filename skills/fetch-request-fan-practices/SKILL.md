---
name: fetch-request-fan-practices
description: 通用 Fetch 请求规范技能。定义统一请求封装、错误处理、拦截器、TypeScript 类型安全、取消请求等最佳实践。
---

# Fetch 请求使用规范

## 适用范围

本技能适用于所有使用 Fetch API 的 React/TypeScript 项目，包括：

- 封装统一的请求工具类
- 请求/响应拦截器
- 错误处理与重试机制
- TypeScript 类型安全
- 取消请求管理

---

## 核心原则

### 1. 统一请求封装

**必须使用统一的 request 工具类**，禁止在组件中直接使用 fetch。

```typescript
// ✅ 正确 - 使用封装的工具类
import { request } from '@/utils/request'

const userData = await request.get('/api/users')

// ❌ 错误 - 禁止直接使用 fetch
const response = await fetch('/api/users')
```

### 2. 错误处理集中化

- 所有 HTTP 错误状态码在拦截器中统一处理
- 业务错误码在响应拦截器中处理
- 组件中只关心业务数据

### 3. 类型安全

- 所有 API 必须有明确的请求/响应类型定义
- 使用泛型支持不同接口返回

---

## 统一 Request 工具类实现

### 基础结构

```typescript
// src/utils/request/index.ts
import { message } from 'antd'

export interface RequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH'
  headers?: HeadersInit
  body?: any
  params?: Record<string, any> // URL 查询参数（自动序列化）
  timeout?: number
  skipErrorHandler?: boolean // 跳过全局错误处理
  skipAuth?: boolean // 跳过 token 注入
  abortSignal?: AbortSignal // 取消信号
}

export interface ApiResponse<T = any> {
  code: number
  data: T
  message: string
}

class Request {
  private baseURL: string
  private timeout: number

  constructor(baseURL: string, timeout: number = 30000) {
    this.baseURL = baseURL
    this.timeout = timeout
  }

  /**
   * 核心请求方法
   */
  async request<T = any>(
    url: string,
    options: RequestOptions = {},
  ): Promise<T> {
    const {
      method = 'GET',
      headers = {},
      body,
      params,
      timeout = this.timeout,
      skipErrorHandler = false,
      skipAuth = false,
      abortSignal,
    } = options

    // 合并 URL 并序列化 params 参数
    let fullUrl = url.startsWith('http') ? url : `${this.baseURL}${url}`
    fullUrl = this.buildUrl(fullUrl, params)

    // ============ 执行请求拦截器 ============
    let finalOptions = await this.runRequestInterceptors({
      method,
      headers,
      body,
      timeout,
      skipErrorHandler,
      skipAuth,
      abortSignal,
    })

    // 从拦截器后的配置中重新解构
    const {
      method: finalMethod,
      headers: finalHeaders,
      body: finalBody,
    } = finalOptions

    // 创建 AbortController 用于超时和手动取消
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), timeout)

    try {
      // 合并请求头
      const requestHeaders: HeadersInit = {
        'Content-Type': 'application/json',
        ...finalHeaders,
      }

      // 构建请求配置
      const config: RequestInit = {
        method: finalMethod,
        headers: requestHeaders,
        signal: abortSignal || controller.signal,
      }

      // 处理请求体
      if (finalBody && finalMethod !== 'GET') {
        config.body = typeof finalBody === 'string' ? finalBody : JSON.stringify(finalBody)
      }

      // 发起请求
      const response = await fetch(fullUrl, config)

      // 清除超时定时器
      clearTimeout(timeoutId)

      // 处理响应
      return await this.handleResponse<T>(response, skipErrorHandler)
    } catch (error) {
      // 清除超时定时器
      clearTimeout(timeoutId)

      // ============ 执行错误拦截器 ============
      throw await this.runErrorInterceptors(error)
    }
  }

  /**
   * 处理响应 - 执行响应拦截器
   */
  private async handleResponse<T>(
    response: Response,
    skipErrorHandler: boolean,
  ): Promise<T> {
    // 检查 HTTP 状态码
    if (!response.ok) {
      if (!skipErrorHandler) {
        this.handleHttpError(response.status)
      }
      throw new Error(`HTTP Error: ${response.status}`)
    }

    // 解析响应数据
    const result: ApiResponse<T> = await response.json()

    // 检查业务状态码
    if (result.code !== 0 && result.code !== 200) {
      if (!skipErrorHandler) {
        message.error(result.message || '请求失败')
      }
      throw new Error(result.message || '请求失败')
    }

    // ============ 执行响应拦截器 ============
    return await this.runResponseInterceptors<T>(result.data)
  }

  /**
   * 处理错误
   */
  private handleError(error: any, skipErrorHandler: boolean): never {
    // 取消请求
    if (error.name === 'AbortError') {
      throw new Error('Request cancelled')
    }

    // 网络错误
    if (!navigator.onLine) {
      if (!skipErrorHandler) {
        message.error('网络连接失败，请检查网络')
      }
      throw new Error('网络连接失败')
    }

    // 超时错误
    if (error.message?.includes('timeout')) {
      if (!skipErrorHandler) {
        message.error('请求超时，请重试')
      }
      throw new Error('请求超时')
    }

    // 其他错误
    if (!skipErrorHandler) {
      message.error(error.message || '请求失败')
    }
    throw error
  }

  /**
   * HTTP 错误状态码处理
   */
  private handleHttpError(status: number): void {
    const errorMessages: Record<number, string> = {
      400: '请求参数错误',
      401: '未授权，请重新登录',
      403: '拒绝访问',
      404: '请求资源不存在',
      500: '服务器内部错误',
      502: '网关错误',
      503: '服务不可用',
      504: '网关超时',
    }

    message.error(errorMessages[status] || `请求失败：${status}`)

    // 401 特殊处理 - 跳转登录
    if (status === 401) {
      this.handleUnauthorized()
    }
  }

  /**
   * 获取 Token
   */
  private getToken(): string | null {
    return localStorage.getItem('token')
  }

  /**
   * 序列化 URL 参数
   */
  private serializeParams(params?: Record<string, any>): string {
    if (!params) return ''

    const searchParams = new URLSearchParams()

    Object.entries(params).forEach(([key, value]) => {
      if (value !== null && value !== undefined) {
        if (Array.isArray(value)) {
          // 数组参数：ids=[1,2,3]
          value.forEach((v) => searchParams.append(key, String(v)))
        } else {
          searchParams.append(key, String(value))
        }
      }
    })

    const queryString = searchParams.toString()
    return queryString ? `?${queryString}` : ''
  }

  /**
   * 构建完整 URL（路径参数 + 查询参数）
   */
  private buildUrl(url: string, params?: Record<string, any>): string {
    if (!params) return url

    const [path, existingQuery] = url.split('?')
    const queryString = this.serializeParams(params)

    if (!queryString) return url
    if (!existingQuery) return `${path}${queryString}`
    return `${path}?${existingQuery}&${queryString.slice(1)}`
  }

  /**
   * 处理未授权
   */
  private handleUnauthorized(): void {
    // 清除本地 token
    localStorage.removeItem('token')
    // 跳转登录页
    window.location.href = '/login'
  }

  // ============ 便捷方法 ============

  /**
   * GET 请求 - 支持路径参数和 params 序列化两种形式
   * @param url - 请求 URL（可直接带参数：`/users/:id` 或 `/users?id=1`）
   * @param paramsOrOptions - 查询参数对象或请求选项
   * @param options - 请求选项（当第二个参数为 params 对象时）
   *
   * @example
   * // 方式 1: 路径传参
   * request.get('/users/123')
   * request.get('/users/:id', { params: { id: '123' } }) // 需要配合模板引擎
   *
   * @example
   * // 方式 2: params 序列化传参
   * request.get('/users', { page: 1, pageSize: 10 })
   * request.get('/users', { page: 1 }, { skipErrorHandler: true })
   *
   * @example
   * // 方式 3: 混合使用
   * request.get('/users/123/posts', { type: 'published' })
   */
  get<T = any>(
    url: string,
    paramsOrOptions?: Record<string, any> | Omit<RequestOptions, 'method' | 'body'>,
    options?: Omit<RequestOptions, 'method' | 'body'>,
  ): Promise<T> {
    // 判断第二个参数是 params 还是 options
    const isParams = paramsOrOptions && !('skipErrorHandler' in paramsOrOptions) && !('skipAuth' in paramsOrOptions)
    
    const finalOptions: RequestOptions = {
      method: 'GET',
      ...options,
      // 如果第二个参数是 params，则合并到 params 中
      params: isParams 
        ? { ...options?.params, ...paramsOrOptions as Record<string, any> }
        : { ...options?.params },
    }

    return this.request<T>(url, finalOptions)
  }

  post<T = any>(
    url: string,
    body?: any,
    options?: Omit<RequestOptions, 'method' | 'body'>,
  ) {
    return this.request<T>(url, { ...options, method: 'POST', body })
  }

  put<T = any>(
    url: string,
    body?: any,
    options?: Omit<RequestOptions, 'method' | 'body'>,
  ) {
    return this.request<T>(url, { ...options, method: 'PUT', body })
  }

  delete<T = any>(url: string, options?: Omit<RequestOptions, 'method'>) {
    return this.request<T>(url, { ...options, method: 'DELETE' })
  }

  patch<T = any>(
    url: string,
    body?: any,
    options?: Omit<RequestOptions, 'method' | 'body'>,
  ) {
    return this.request<T>(url, { ...options, method: 'PATCH', body })
  }
}

// 导出单例
export const request = new Request(process.env.REACT_APP_API_URL || '/api')
```

---

## 使用方式

### 基础用法

```typescript
// src/services/user.ts
import { request } from '@/utils/request'
import type { User, LoginParams, LoginResponse } from './types'

/**
 * 获取用户信息
 */
export const getUserInfo = () => {
  return request.get<User>('/user/info')
}

/**
 * 登录
 */
export const login = (params: LoginParams) => {
  return request.post<LoginResponse>('/user/login', params)
}

/**
 * 更新用户信息
 */
export const updateUserInfo = (data: Partial<User>) => {
  return request.put<User>('/user/info', data)
}

/**
 * 删除用户
 */
export const deleteUser = (id: string) => {
  return request.delete(`/user/${id}`)
}
```

### GET 请求参数传参方式

#### 方式一：路径传参（适用于 RESTful 风格）

```typescript
// 直接拼接路径
request.get(`/users/${userId}`)

// 或使用模板字符串
const url = `/users/${userId}/posts/${postId}`
request.get(url)
```

#### 方式二：params 序列化传参（适用于查询参数）

```typescript
// 简单参数
request.get('/users', { page: 1, pageSize: 10 })
// => GET /users?page=1&pageSize=10

// 多条件查询
request.get('/users', { 
  status: 'active', 
  role: 'admin',
  keyword: 'test'
})
// => GET /users?status=active&role=admin&keyword=test

// 数组参数
request.get('/users', { 
  ids: [1, 2, 3],
  tags: ['frontend', 'react']
})
// => GET /users?ids=1&ids=2&ids=3&tags=frontend&tags=react
```

#### 方式三：混合使用（路径 + 查询参数）

```typescript
// 路径带参数，同时有查询参数
request.get(`/users/${userId}/posts`, { page: 1, type: 'published' })
// => GET /users/123/posts?page=1&type=published

// 带选项的查询
request.get(
  `/users/${userId}`,
  { include: 'posts,comments' },
  { skipErrorHandler: true }
)
```

#### 方式四：完整选项

```typescript
// 使用完整 options 形式
request.get('/users', {
  params: { page: 1, pageSize: 10 },
  timeout: 5000,
  skipAuth: false,
})
```

### 组件中使用

```typescript
// src/pages/UserProfile.tsx
import { useEffect, useState } from 'react'
import { getUserInfo } from '@/services/user'
import type { User } from '@/services/types'

function UserProfile() {
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    getUserInfo()
      .then(setUser)
      .finally(() => setLoading(false))
  }, [])

  if (loading) return <div>加载中...</div>
  if (!user) return <div>无数据</div>

  return <div>{user.name}</div>
}
```

---

## 请求/响应拦截器

### 请求拦截器

在 request 工具类中添加请求拦截器支持：

```typescript
// src/utils/request/interceptors.ts
import type { AxiosRequestConfig, AxiosResponse } from 'axios'

---

## 拦截器实现与使用

### 完整实现代码

```typescript
// src/utils/request/index.ts
import { message } from 'antd'

export interface RequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH'
  headers?: HeadersInit
  body?: any
  params?: Record<string, any>
  timeout?: number
  skipErrorHandler?: boolean
  skipAuth?: boolean
  abortSignal?: AbortSignal
}

export interface ApiResponse<T = any> {
  code: number
  data: T
  message: string
}

// ============ 拦截器类型定义 ============
export type RequestInterceptor = (
  config: RequestOptions,
) => RequestOptions | Promise<RequestOptions>

export type ResponseInterceptor<T = any> = (
  response: T,
) => T | Promise<T>

export type ErrorInterceptor = (
  error: any,
) => any | Promise<any>

class Request {
  private baseURL: string
  private timeout: number
  // 拦截器队列
  private requestInterceptors: RequestInterceptor[] = []
  private responseInterceptors: ResponseInterceptor[] = []
  private errorInterceptors: ErrorInterceptor[] = []

  constructor(baseURL: string, timeout: number = 30000) {
    this.baseURL = baseURL
    this.timeout = timeout
  }

  // ============ 拦截器注册方法 ============

  /**
   * 添加请求拦截器
   * @param interceptor 请求拦截器函数
   */
  addRequestInterceptor(interceptor: RequestInterceptor) {
    this.requestInterceptors.push(interceptor)
  }

  /**
   * 添加响应拦截器
   * @param interceptor 响应拦截器函数
   */
  addResponseInterceptor<T>(interceptor: ResponseInterceptor<T>) {
    this.responseInterceptors.push(interceptor)
  }

  /**
   * 添加错误拦截器
   * @param interceptor 错误拦截器函数
   */
  addErrorInterceptor(interceptor: ErrorInterceptor) {
    this.errorInterceptors.push(interceptor)
  }

  // ============ 拦截器执行方法 ============

  /**
   * 执行请求拦截器链
   */
  private async runRequestInterceptors(
    config: RequestOptions,
  ): Promise<RequestOptions> {
    let newConfig = config
    for (const interceptor of this.requestInterceptors) {
      newConfig = await interceptor(newConfig)
    }
    return newConfig
  }

  /**
   * 执行响应拦截器链
   */
  private async runResponseInterceptors<T>(response: T): Promise<T> {
    let newResponse = response
    for (const interceptor of this.responseInterceptors) {
      newResponse = await interceptor(newResponse)
    }
    return newResponse
  }

  /**
   * 执行错误拦截器链
   */
  private async runErrorInterceptors(error: any): Promise<any> {
    let newError = error
    for (const interceptor of this.errorInterceptors) {
      newError = await interceptor(newError)
    }
    return newError
  }
}

// 导出单例
export const request = new Request(process.env.REACT_APP_API_URL || '/api')
```

---

## 拦截器使用示例

### 执行流程

```
发起请求
    ↓
[请求拦截器 1] → [请求拦截器 2] → [请求拦截器 3]
    ↓              ↓                ↓
  修改 config   添加 token      添加时间戳
    ↓
执行 fetch 请求
    ↓
[响应拦截器 1] → [响应拦截器 2]
    ↓              ↓
  数据转换      空值处理
    ↓
返回给用户

发生错误时:
    ↓
[错误拦截器 1] → [错误拦截器 2]
    ↓              ↓
  401 处理     错误上报
```

### 场景一：添加 Token

```typescript
// src/utils/request/interceptors/auth.ts
import { request } from './index'

// 请求拦截器：自动注入 token
request.addRequestInterceptor(async (config) => {
  // 如果请求需要认证（默认都需要，除非设置 skipAuth: true）
  if (!config.skipAuth) {
    const token = localStorage.getItem('token')
    if (token) {
      config.headers = {
        ...config.headers,
        Authorization: `Bearer ${token}`,
      }
    }
  }
  return config
})
```

### 场景二：防止 GET 请求缓存

```typescript
// src/utils/request/interceptors/cache.ts
import { request } from './index'

// 请求拦截器：为 GET 请求添加时间戳防止缓存
request.addRequestInterceptor((config) => {
  if (config.method === 'GET' && config.url) {
    const separator = config.url.includes('?') ? '&' : '?'
    config.url = `${config.url}${separator}_t=${Date.now()}`
  }
  return config
})
```

### 场景三：统一响应数据处理

```typescript
// src/utils/request/interceptors/response.ts
import { message } from 'antd'
import { request } from './index'

// 响应拦截器：空数据提示
request.addResponseInterceptor((data) => {
  // 如果响应数据为空，返回默认值
  if (data === null || data === undefined) {
    return [] as any
  }
  return data
})

// 响应拦截器：成功提示（可选）
request.addResponseInterceptor((data) => {
  // 某些操作成功后提示
  if (data?.successMessage) {
    message.success(data.successMessage)
  }
  return data
})
```

### 场景四：Token 过期刷新

```typescript
// src/utils/request/interceptors/token-refresh.ts
import { request } from './index'
import { refreshTokenApi } from '@/services/auth'

let isRefreshing = false
let refreshPromise: Promise<string> | null = null
const pendingRequests: Array<{
  resolve: (token: string) => void
  reject: (error: any) => void
}> = []

// 错误拦截器：处理 401 未授权
request.addErrorInterceptor(async (error) => {
  const originalRequest = error.config

  // 如果是 401 错误且不是刷新 token 的请求
  if (error.status === 401 && !originalRequest._retry) {
    originalRequest._retry = true

    // 如果正在刷新 token，将请求加入队列
    if (isRefreshing) {
      return new Promise((resolve, reject) => {
        pendingRequests.push({ resolve, reject })
      }).then((token) => {
        originalRequest.headers.Authorization = `Bearer ${token}`
        return request.request(originalRequest.url, originalRequest)
      })
    }

    // 开始刷新 token
    isRefreshing = true
    refreshPromise = refreshTokenApi()
      .then((newToken) => {
        // 刷新成功，通知队列中的请求
        pendingRequests.forEach(({ resolve }) => resolve(newToken))
        pendingRequests.length = 0
        return newToken
      })
      .catch((err) => {
        // 刷新失败，通知队列中的请求
        pendingRequests.forEach(({ reject }) => reject(err))
        pendingRequests.length = 0
        // 跳转登录
        window.location.href = '/login'
        throw err
      })
      .finally(() => {
        isRefreshing = false
      })

    try {
      const newToken = await refreshPromise
      originalRequest.headers.Authorization = `Bearer ${newToken}`
      // 重试原请求
      return request.request(originalRequest.url, originalRequest)
    } catch {
      throw error
    }
  }

  throw error
})
```

### 场景五：请求日志记录

```typescript
// src/utils/request/interceptors/logger.ts
import { request } from './index'

// 请求拦截器：记录请求日志
request.addRequestInterceptor((config) => {
  console.group(`[HTTP] ${config.method} ${config.url}`)
  console.log('Request:', config)
  console.time(`[HTTP] ${config.method}`)
  return config
})

// 响应拦截器：记录响应日志
request.addResponseInterceptor((data) => {
  console.log('Response:', data)
  console.timeEnd(`[HTTP] ${config.method}`)
  console.groupEnd()
  return data
})

// 错误拦截器：记录错误日志
request.addErrorInterceptor((error) => {
  console.error('[HTTP Error]', error)
  console.groupEnd()
  throw error
})
```

### 场景六：请求 Loading 状态

```typescript
// src/utils/request/interceptors/loading.ts
import { Spin } from 'antd'
import { request } from './index'

// 请求拦截器：显示 loading
request.addRequestInterceptor((config) => {
  if (!config.skipLoading) {
    Spin.show()
  }
  return config
})

// 响应拦截器：隐藏 loading
request.addResponseInterceptor((data) => {
  Spin.hide()
  return data
})

// 错误拦截器：隐藏 loading
request.addErrorInterceptor((error) => {
  Spin.hide()
  throw error
})
```

### 在 setup 文件中统一注册拦截器

```typescript
// src/utils/request/setup.ts
import { request } from './index'

// 导入所有拦截器（在拦截器文件中会自动注册）
import './interceptors/auth'
import './interceptors/cache'
import './interceptors/response'
import './interceptors/token-refresh'

// 应用启动时执行一次
export function setupRequestInterceptors() {
  console.log('Request interceptors initialized')
}
```

### 在入口文件中初始化

```typescript
// src/main.tsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import { setupRequestInterceptors } from './utils/request/setup'
import App from './App'

// 初始化请求拦截器
setupRequestInterceptors()

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
```

---

## 取消请求

### 使用 AbortController

```typescript
// src/hooks/useAbortableRequest.ts
import { useEffect, useRef } from 'react'

export function useAbortableRequest() {
  const controllerRef = useRef<AbortController | null>(null)

  useEffect(() => {
    // 组件卸载时取消请求
    return () => {
      controllerRef.current?.abort()
    }
  }, [])

  const request = (url: string, options?: RequestInit) => {
    // 取消之前的请求
    controllerRef.current?.abort()

    // 创建新的控制器
    controllerRef.current = new AbortController()

    return fetch(url, {
      ...options,
      signal: controllerRef.current.signal,
    })
  }

  return request
}
```

### 在组件中使用

```typescript
import { useAbortableRequest } from '@/hooks/useAbortableRequest'

function SearchComponent() {
  const abortableRequest = useAbortableRequest()
  const [results, setResults] = useState([])

  const handleSearch = async (query: string) => {
    try {
      const response = await abortableRequest(`/api/search?q=${query}`)
      const data = await response.json()
      setResults(data)
    } catch (error) {
      if (error.name !== 'AbortError') {
        console.error('Search error:', error)
      }
    }
  }

  return <SearchBox onSearch={handleSearch} />
}
```

---

## 重试机制

### 指数退避重试

```typescript
// src/utils/request/retry.ts
export interface RetryConfig {
  retries?: number
  backoff?: number // 基础退避时间 (ms)
  maxBackoff?: number // 最大退避时间 (ms)
}

export async function fetchWithRetry(
  url: string,
  options: RequestInit = {},
  config: RetryConfig = {},
): Promise<Response> {
  const { retries = 3, backoff = 1000, maxBackoff = 10000 } = config

  let lastError: Error | null = null

  for (let i = 0; i <= retries; i++) {
    try {
      const response = await fetch(url, options)

      // 成功则直接返回
      if (response.ok || i === retries) {
        return response
      }

      // 服务器错误，考虑重试
      if (response.status >= 500) {
        throw new Error(`Server error: ${response.status}`)
      }

      return response
    } catch (error) {
      lastError = error as Error

      // 最后一次重试失败，抛出错误
      if (i === retries) {
        break
      }

      // 计算退避时间（指数退避 + 抖动）
      const delay = Math.min(
        backoff * Math.pow(2, i) * (0.5 + Math.random()),
        maxBackoff,
      )

      await new Promise((resolve) => setTimeout(resolve, delay))
    }
  }

  throw lastError || new Error('Request failed')
}
```

---

## 类型定义规范

### API 类型定义

```typescript
// src/services/types/index.ts

// 通用分页参数
export interface PageParams {
  page: number
  pageSize: number
}

// 通用分页响应
export interface PageResponse<T> {
  list: T[]
  total: number
  page: number
  pageSize: number
}

// 通用 API 响应
export interface ApiResponse<T = any> {
  code: number
  data: T
  message: string
  timestamp?: number
}

// 用户相关类型
export interface User {
  id: string
  name: string
  email: string
  avatar?: string
  role: 'admin' | 'user' | 'guest'
}

export interface LoginParams {
  username: string
  password: string
  captcha: string
}

export interface LoginResponse {
  token: string
  refreshToken: string
  user: User
}
```

### 服务层类型定义

```typescript
// src/services/user.ts
import { request } from '@/utils/request'
import type {
  User,
  LoginParams,
  LoginResponse,
  PageParams,
  PageResponse,
} from './types'

// 用户服务
export const userService = {
  // 获取用户信息
  getInfo: () => request.get<User>('/user/info'),

  // 登录
  login: (params: LoginParams) =>
    request.post<LoginResponse>('/user/login', params),

  // 登出
  logout: () => request.post('/user/logout'),

  // 获取用户列表 - params 作为第二个参数
  getList: (params: PageParams) =>
    request.get<PageResponse<User>>('/user/list', params),

  // 获取用户列表 - 带额外选项
  getListWithOptions: (params: PageParams) =>
    request.get<PageResponse<User>>('/user/list', params, { timeout: 10000 }),

  // 创建用户
  create: (data: Partial<User>) =>
    request.post<User>('/user', data),

  // 更新用户
  update: (id: string, data: Partial<User>) =>
    request.put<User>(`/user/${id}`, data),

  // 删除用户 - 路径传参
  delete: (id: string) => request.delete(`/user/${id}`),

  // 获取用户详情 - 路径传参
  getDetail: (id: string) => request.get<User>(`/user/${id}`),
}
```

---

## 最佳实践

### 1. 环境变量配置

```bash
# .env.development
REACT_APP_API_URL=http://localhost:3000/api

# .env.production
REACT_APP_API_URL=https://api.example.com
```

```typescript
// src/utils/request/config.ts
export const config = {
  baseURL:
    process.env.NODE_ENV === 'development'
      ? process.env.REACT_APP_API_URL
      : process.env.REACT_APP_API_URL_PROD,
  timeout: 30000,
}
```

### 3. 文件上传

```typescript
// src/services/upload.ts
import { request } from '@/utils/request'

export const uploadService = {
  /**
   * 单文件上传
   */
  uploadFile: async (file: File, onProgress?: (percent: number) => void) => {
    const formData = new FormData()
    formData.append('file', file)

    // 文件上传需要跳过默认 Content-Type
    return request.post<{ url: string }>('/upload/file', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
      // 可以在这里添加上传进度监听
    })
  },

  /**
   * 多文件上传
   */
  uploadFiles: async (files: File[]) => {
    const formData = new FormData()
    files.forEach((file) => formData.append('files', file))

    return request.post<{ urls: string[] }>('/upload/files', formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    })
  },
}
```

### 4. 下载文件

```typescript
// src/services/download.ts

/**
 * 下载文件
 */
export const downloadFile = async (url: string, filename?: string) => {
  try {
    const response = await fetch(url, {
      headers: {
        Authorization: `Bearer ${localStorage.getItem('token')}`,
      },
    })

    if (!response.ok) {
      throw new Error('下载失败')
    }

    const blob = await response.blob()
    const downloadUrl = window.URL.createObjectURL(blob)

    const link = document.createElement('a')
    link.href = downloadUrl
    link.download = filename || 'download'
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)

    window.URL.revokeObjectURL(downloadUrl)
  } catch (error) {
    console.error('Download error:', error)
    throw error
  }
}
```

### 5. 请求去重

```typescript
// src/utils/request/deduplication.ts

class RequestDeduplication {
  private pendingRequests = new Map<string, Promise<any>>()

  /**
   * 生成请求缓存 key
   */
  private generateKey(url: string, options: RequestOptions): string {
    return `${options.method || 'GET'}:${url}:${JSON.stringify(options.body || {})}`
  }

  /**
   * 执行带去重的请求
   */
  async request<T>(
    url: string,
    options: RequestOptions,
    executor: () => Promise<T>,
  ): Promise<T> {
    const key = this.generateKey(url, options)

    // 如果已有相同请求，返回已有的 promise
    if (this.pendingRequests.has(key)) {
      return this.pendingRequests.get(key)!
    }

    // 执行请求
    const promise = executor().finally(() => {
      this.pendingRequests.delete(key)
    })

    this.pendingRequests.set(key, promise)
    return promise
  }

  /**
   * 取消指定请求
   */
  cancel(key: string): void {
    this.pendingRequests.delete(key)
  }

  /**
   * 取消所有请求
   */
  cancelAll(): void {
    this.pendingRequests.clear()
  }
}

export const requestDeduplication = new RequestDeduplication()
```

---

## 注意事项

### ✅ 正确做法

1. **统一使用封装的 request 工具类**
2. **在拦截器中统一处理错误和认证**
3. **所有 API 必须有明确的类型定义**
4. **敏感操作需要二次确认**
5. **大文件上传需要分片和进度提示**
6. **列表接口需要处理分页和加载状态**
7. **使用环境变量区分不同环境**

### ❌ 错误做法

```typescript
// ❌ 错误：在组件中直接使用 fetch
const response = await fetch('/api/users')

// ❌ 错误：没有错误处理
const data = await fetch('/api/users').then((r) => r.json())

// ❌ 错误：硬编码 API 地址
const url = 'http://localhost:3000/api/users'

// ❌ 错误：在代码中硬编码 token
const token = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'

// ❌ 错误：没有取消机制导致内存泄漏
useEffect(() => {
  fetchData() // 没有清理函数
}, [])
```

---

## 与 React Query 集成

```typescript
// src/hooks/api/useUser.ts
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { userService } from '@/services/user'
import type { User, LoginParams, PageParams } from '@/services/types'

// 查询 keys
export const userKeys = {
  all: ['users'] as const,
  lists: () => [...userKeys.all, 'list'] as const,
  list: (filters: PageParams) => [...userKeys.lists(), filters] as const,
  details: () => [...userKeys.all, 'detail'] as const,
  detail: (id: string) => [...userKeys.details(), id] as const,
}

// 获取用户信息
export function useUserInfo() {
  return useQuery({
    queryKey: userKeys.detail('me'),
    queryFn: () => userService.getInfo(),
  })
}

// 获取用户列表
export function useUserList(params: PageParams) {
  return useQuery({
    queryKey: userKeys.list(params),
    queryFn: () => userService.getList(params),
  })
}

// 登录
export function useLogin() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (params: LoginParams) => userService.login(params),
    onSuccess: () => {
      // 登录成功后刷新用户数据
      queryClient.invalidateQueries({ queryKey: userKeys.all })
    },
  })
}

// 更新用户信息
export function useUpdateUser() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ id, data }: { id: string; data: Partial<User> }) =>
      userService.update(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: userKeys.details() })
    },
  })
}
```

---

## API 测试

### Mock 数据

```typescript
// src/services/__mocks__/user.ts
import type { User, LoginParams, LoginResponse } from '../types'

const mockUsers: User[] = [
  { id: '1', name: '张三', email: 'zhangsan@example.com', role: 'admin' },
  { id: '2', name: '李四', email: 'lisi@example.com', role: 'user' },
]

export const userService = {
  getInfo: async () => mockUsers[0],
  login: async (params: LoginParams) => {
    // 模拟登录验证
    if (params.username === 'admin' && params.password === '123456') {
      return {
        token: 'mock-token',
        refreshToken: 'mock-refresh-token',
        user: mockUsers[0],
      } as LoginResponse
    }
    throw new Error('用户名或密码错误')
  },
  getList: async () => ({
    list: mockUsers,
    total: mockUsers.length,
    page: 1,
    pageSize: 10,
  }),
}
```

---

## 性能优化

### 1. 请求合并

```typescript
// 使用 Promise.all 合并并发请求
const [users, roles, permissions] = await Promise.all([
  userService.getList(),
  roleService.getList(),
  permissionService.getList(),
])
```

### 2. 请求缓存

```typescript
// 使用 Map 实现简单缓存
const cache = new Map<string, { data: any; timestamp: number }>()
const CACHE_TTL = 5 * 60 * 1000 // 5 分钟

export function getWithCache<T>(key: string): T | null {
  const cached = cache.get(key)
  if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
    return cached.data as T
  }
  return null
}

export function setCache(key: string, data: any) {
  cache.set(key, { data, timestamp: Date.now() })
}
```

---

## 总结

| 场景 | 推荐做法 |
| --- | --- |
| 基础请求 | 使用统一的 request 工具类 |
| 错误处理 | 在拦截器中统一处理 |
| 认证 | 请求拦截器自动注入 token |
| 取消请求 | 使用 AbortController |
| 重试 | 指数退避策略 |
| 类型安全 | 定义明确的请求/响应类型 |
| 状态管理 | 集成 React Query |
| 环境配置 | 使用环境变量区分环境 |
