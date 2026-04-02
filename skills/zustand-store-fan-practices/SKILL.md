---
name: zustand-store-fan-practices
description: 通用 Zustand Store 使用规范技能。定义组件中使用 useShallow 的推荐写法、getState 的使用边界、传统单 Store 与 Slice 模式实践，以及 subscribeWithSelector 订阅方式。
---

# Zustand Store 使用规范

## 适用范围

本技能适用于所有使用 Zustand 的 React/TypeScript 项目，包括：

- 组件中消费 store 状态
- 调用 store 中的方法
- Store 的创建规范（传统模式 和 Slice 模式）
- 使用 subscribeWithSelector 进行订阅

## 组件中使用 Store 的正确方式

**必须使用 `useShallow` 解构使用**，禁止在组件中直接使用 `getState()` 获取值来使用。**解构不要在 useEffect 中直接调用**，应该在组件主体中解构后使用。

### ✅ 正确用法 - 解构为对象

```typescript
import { useCustomLayerStore } from '@/store/models/useCustomLayerStore'
import { useShallow } from 'zustand/shallow'

// 方式 1: 解构为对象
const { fetchLayerData, layerOptions } = useCustomLayerStore(
  useShallow((state) => ({
    fetchLayerData: state.fetchLayerData,
    layerOptions: state.layerOptions,
  })),
)
```

### ✅ 正确用法 - 解构为数组

```typescript
import { useMapLayerStore } from '@/pages/mapLayer/store'
import { useShallow } from 'zustand/shallow'

// 方式 2: 解构为数组
const [layerSwitches, updateLayerSwitch] = useMapLayerStore(
  useShallow((state) => [state.layerSwitches, state.updateLayerSwitch]),
)
```

### ❌ 错误用法 - 禁止直接使用 getState()

```typescript
// 错误：不要在组件中这样使用
const layerOptions = useCustomLayerStore.getState().layerOptions
const fetchLayerData = useCustomLayerStore.getState().fetchLayerData

// 错误：不要在 useEffect 中这样调用
useEffect(() => {
  useCustomLayerStore.getState().fetchLayerData() // ❌
}, [])
```

## 使用原则

1. **组件内消费状态**：必须使用 `useShallow` hook 解构，避免不必要的重渲染
2. **初始化和非组件场景**：可以使用 `getState()` 调用方法（如在 router、interceptor 等非组件文件中）
3. **解构形式**：要么解构为对象，要么解构为数组，保持代码一致性

---

# 传统单 Store 模式

适用于功能简单、状态较少的场景。

### 基本结构

```typescript
import { createWithEqualityFn as create } from 'zustand/traditional'
import { message } from 'antd'

// 1. 定义类型
interface MyStore {
  // 状态
  dataList: any[]
  // 方法
  fetchData: () => Promise<void>
  updateList: (newList: any[]) => void
}

// 2. 创建 store
const useMyStore = create<MyStore>((set, get) => ({
  // 初始状态
  dataList: [],

  // 方法实现
  fetchData: async () => {
    try {
      const res = await someApi()
      set({ dataList: res.data })
    } catch (error) {
      message.error('获取数据失败')
    }
  },

  updateList: (newList) => set({ dataList: newList }),
}))

export default useMyStore
```

### 关键点

1. **使用 `createWithEqualityFn`**：从 `zustand/traditional` 导入
2. **不使用 devtools 包装**：直接在 `create()` 中定义
3. **使用 `set` 更新状态**：在方法内部使用 `set()` 或 `set((state) => ({...}))`
4. **定义 interface 类型**：包含所有状态和方法

---

# Slice 模式（推荐）

适用于功能复杂、需要按模块拆分状态的中大型项目。

## 什么是 Slice 模式？

Slice 模式是将 store 按功能拆分成独立的"切片"（slice），每个 slice 管理自己独立的状态和行为，最后合并成一个统一的 store。

### 优势

1. **代码组织更清晰** - 相关状态和 action 按功能聚合
2. **易于维护和扩展** - 每个 slice 独立，互不干扰
3. **更好的类型推导** - TypeScript 类型更安全
4. **避免 store 碎片化** - 单一 store 入口，统一消费

## 目录结构

```
src/store/
├── index.ts              # 统一导出
├── useAppStore.ts        # 主 store 入口（合并所有 slices）
└── slices/               # slices 目录
    ├── types.ts          # 所有 slice 的类型定义
    ├── userSlice.ts      # 用户相关 slice
    ├── businessSlice.ts  # 业务相关 slice
    └── mapSlice.ts       # 地图相关 slice
```

## 创建 Slice 的步骤

### 第一步：定义类型 (src/store/slices/types.ts)

```typescript
// 各个 Slice 的类型定义
export interface UserSlice {
  // State
  token: string
  userInfo: Record<string, any>
  menuConfig: MenuConfig
  authList: AuthList
  // Actions
  setToken: (token: string) => void
  getUserInfo: () => Promise<boolean>
  getAuthList: () => Promise<boolean>
  logout: () => void
}

export interface BusinessSlice {
  // State
  focusBrandOptions: SelectItemType[]
  brandOptions: SelectItemType[]
  tenantOptions: SelectItemType[]
  // Actions
  getBrandOptions: (val: string) => Promise<boolean>
  getTenantOptions: () => Promise<boolean>
  getAllFocusBrand: () => Promise<boolean>
}

// 合并后的 Store 类型（所有 Slice 的交集）
export type AppStore = UserSlice & BusinessSlice
```

### 第二步：创建独立的 Slice

每个 slice 是一个独立的文件，导出一个 `createXXXSlice` 函数：

```typescript
// src/store/slices/userSlice.ts
import { StateCreator } from 'zustand'
import { storage } from '@mango-kit/utils'
import { createMenu, createAuthList } from '@/router'
import * as API from '@/services/login'
import sso from '@/utils/sso'
import type { UserSlice } from './types'

const getAccessToken = () => {
  const url = new URL(window.location.href)
  const xAccessToken = url.searchParams.get('x-access-token')
  if (xAccessToken) {
    storage.setItem('TOKEN', xAccessToken)
    url.searchParams.delete('x-access-token')
    window.history.replaceState({}, document.title, url.toString())
  }
  return false
}

export const createUserSlice: StateCreator<UserSlice, [], [], UserSlice> = (
  set,
  get,
) => ({
  // 初始状态
  token: storage.getItem('TOKEN', '') || '',
  userInfo: {},
  menuConfig: [],
  authList: [],

  // Action: 设置 token
  setToken: (token) => set({ token }),

  // Action: 登录
  login: async () => sso.login(),

  // Action: 获取用户信息
  getUserInfo: async () => {
    const { code, data } = await API.getUserInfo()
    if (code === 0) {
      storage.setItem('USER_NAME', data?.name)
      set({ userInfo: data })
      return true
    }
    return false
  },

  // Action: 获取权限列表
  getAuthList: async () => {
    const { code, data } = await API.getPriv()
    if (code === 0) {
      const { moduleList = [] } = data
      const list =
        moduleList?.find((i) => i?.path === '/geo-netbrain')?.navList ?? []
      set({
        menuConfig: createMenu(list),
        authList: createAuthList(list),
      })
      return true
    }
    return false
  },

  // Action: 登出
  logout: () => {
    set({ token: '', userInfo: {}, menuConfig: [], authList: [] })
    storage.removeItem('TOKEN')
    sso.logout()
  },
})
```

### 第三步：合并所有 Slice 创建主 Store

```typescript
// src/store/useAppStore.ts
import { createWithEqualityFn as create } from 'zustand/traditional'
import { devtools } from 'zustand/middleware'
import type { AppStore } from './slices/types'
import { createUserSlice } from './slices/userSlice'
import { createBusinessSlice } from './slices/businessSlice'

const useAppStore = create<AppStore>()(
  devtools((...args) => ({
    // 展开所有 slice
    ...createUserSlice(...args),
    ...createBusinessSlice(...args),
    // 添加新的 slice 时继续展开
    // ...createMapSlice(...args),
  })),
)

export { useAppStore }
```

### 第四步：统一导出

```typescript
// src/store/index.ts
export { useAppStore } from './useAppStore'

// 保留旧的 store 导出（兼容过渡，逐步迁移）
export { default as useUserStore } from './models/useUserStore'
export { default as useBusinessStore } from './models/useBusinessStore'
```

## Slice 模式的关键规范

### 1. Slice 函数签名

每个 slice 必须使用 `StateCreator<T, [], [], T>` 类型：

```typescript
export const createXXXSlice: StateCreator<XXXSlice, [], [], XXXSlice> = (
  set,
  get,
) => ({
  // ...
})
```

### 2. 在 Slice 中调用其他 Slice 的状态/方法

通过 `get()` 参数访问其他 slice 的状态：

```typescript
export const createBusinessSlice: StateCreator<
  BusinessSlice,
  [],
  [],
  BusinessSlice
> = (set, get) => ({
  // ...
  someAction: async () => {
    // 访问 userSlice 的状态
    const token = get().token
    // 调用 userSlice 的方法
    await get().getUserInfo()
  },
})
```

### 3. 更新状态

必须使用 `set()` 函数，禁止直接修改状态：

```typescript
// ✅ 正确
set({ token: 'new-token' })
set((state) => ({ count: state.count + 1 }))

// ❌ 错误 - 禁止直接修改
state.token = 'new-token'
```

### 4. 异步 Action 中的状态更新

```typescript
fetchData: async () => {
  try {
    set({ loading: true }) // 更新加载状态
    const res = await someApi()
    set({ data: res.data, loading: false })
  } catch (error) {
    set({ loading: false, error: error.message })
  }
}
```

## 组件中使用 Slice Store

与传统模式相同，必须使用 `useShallow`：

```typescript
import { useAppStore } from '@/store'
import { useShallow } from 'zustand/shallow'

function MyComponent() {
  // 方式 1: 解构为对象
  const { token, userInfo, setToken } = useAppStore(
    useShallow((state) => ({
      token: state.token,
      userInfo: state.userInfo,
      setToken: state.setToken,
    }))
  )

  // 方式 2: 选择器形式
  const token = useAppStore(useShallow((state) => state.token))
  const authList = useAppStore(useShallow((state) => state.authList))

  return <div>{token}</div>
}
```

## 何时选择哪种模式？

| 场景                    | 推荐模式                 |
| ----------------------- | ------------------------ |
| 小型项目 / 简单功能     | 传统单 Store             |
| 中大型项目 / 多模块     | Slice 模式               |
| 已有传统 store 需要重构 | Slice 模式（渐进式迁移） |
| 新增复杂功能模块        | Slice 模式               |

## 从传统模式迁移到 Slice 模式

1. **创建 slices 目录结构**
2. **逐个功能拆分** - 将原有 store 按功能拆分为独立 slice
3. **创建主 store 合并所有 slice**
4. **更新组件引用** - 将 `useUserStore` 改为 `useAppStore((s) => s.xxx)`
5. **保留旧 store 导出** - 兼容过渡，逐步替换

---

# subscribeWithSelector 订阅

`subscribeWithSelector` 是 Zustand 的中间件，用于在非 React 组件场景中订阅特定状态的变化。它允许你订阅状态的某个片段，而不是整个状态对象。

## 适用场景

- **非 React 组件中监听状态变化** - 如在工具函数、地图操作类、全局事件处理中
- **需要精确订阅某个状态字段** - 避免不必要的回调触发
- **需要取消订阅** - 手动管理订阅生命周期

## 导入方式

```typescript
import { subscribeWithSelector } from 'zustand/middleware'
```

## 在 Store 中启用

必须在创建 store 时包装 `subscribeWithSelector` 中间件：

```typescript
import { createWithEqualityFn as create } from 'zustand/traditional'
import { subscribeWithSelector } from 'zustand/middleware'

interface MyStore {
  count: number
  name: string
  setCount: (count: number) => void
  setName: (name: string) => void
}

const useMyStore = create<MyStore>()(
  subscribeWithSelector((set, get) => ({
    count: 0,
    name: '',
    setCount: (count) => set({ count }),
    setName: (name) => set({ name }),
  })),
)

export { useMyStore }
```

## 订阅单个状态变化

**函数签名**：

```typescript
subscribe<U>(
  selector: (state: T) => U,
  listener: (selectedState: U, previousSelectedState: U) => void,
  options?: {
    equalityFn?: (a: U, b: U) => boolean;  // 自定义相等性判断
    fireImmediately?: boolean;             // 是否立即触发一次
  }
): () => void
```

**基础用法**：

```typescript
// 只订阅 count 的变化
const unsubscribe = useMyStore.subscribe(
  (state) => state.count, // 选择器：返回要订阅的值
  (count, prevCount) => {
    console.log('count 发生了变化:', prevCount, '->', count)
  },
)

// 取消订阅
unsubscribe()
```

### 选项参数详解

#### 1. `equalityFn` - 自定义相等性判断

当需要深度比较或自定义比较逻辑时使用：

```typescript
// 使用深度比较
const unsubscribe = useMyStore.subscribe(
  (state) => state.userInfo,
  (userInfo, prevUserInfo) => {
    console.log('用户信息发生变化')
  },
  {
    // 自定义相等性判断：只有 id 变化时才触发
    equalityFn: (a, b) => a.id === b.id,
  },
)

// 数组内容比较（忽略顺序）
useMyStore.subscribe(
  (state) => state.selectedIds,
  (ids) => {
    console.log('选中的 ID 列表发生变化')
  },
  {
    equalityFn: (a, b) => {
      if (a.length !== b.length) return false
      const sortedA = [...a].sort()
      const sortedB = [...b].sort()
      return sortedA.every((val, i) => val === sortedB[i])
    },
  },
)
```

#### 2. `fireImmediately` - 立即触发

设置为 `true` 时，订阅成立即刻触发一次回调：

```typescript
// 立即执行一次，之后只在状态变化时触发
const unsubscribe = useMyStore.subscribe(
  (state) => state.count,
  (count) => {
    console.log('当前 count:', count)
    // 可以在这里初始化某些依赖于 count 的逻辑
  },
  {
    fireImmediately: true, // 订阅后立刻执行一次回调
  },
)
```

**典型应用场景**：

```typescript
// MapOperation 中初始化时立即获取当前 heatmap 状态
useHeatMapJoinStore.subscribe(
  (state) => state.multiScaleHeatMap,
  (data) => {
    // fireImmediately: true 确保初始化时也能获取到数据
    if (data) {
      this.initHeatMapLayer(data)
    }
  },
  { fireImmediately: true },
)
```

## 订阅多个状态变化

使用对象解构返回多个值，当任意一个值变化时触发回调：

```typescript
const unsubscribe = useMyStore.subscribe(
  (state) => ({ count: state.count, name: state.name }),
  (current, previous) => {
    console.log('count 或 name 发生了变化', current, previous)
  },
)
```

---

## 完整 API 参考

根据 Zustand 官方类型定义，`subscribe` 方法有两种重载形式：

### 形式 1：无选择器（订阅整个状态）

```typescript
subscribe(
  listener: (state: T, previousState: T) => void
): () => void
```

当不传入选择器时，每次状态变化都会触发回调（**不推荐**，会导致频繁触发）：

```typescript
// ❌ 不推荐：任何状态变化都会触发
useMyStore.subscribe((state, prevState) => {
  console.log('任何状态变化都会触发这个回调')
})

// ✅ 推荐：使用选择器精确订阅
useMyStore.subscribe(
  (state) => state.count,
  (count) => {
    console.log('只有 count 变化才会触发')
  },
)
```

### 形式 2：带选择器（推荐）

```typescript
subscribe<U>(
  selector: (state: T) => U,           // 选择器函数
  listener: (selected: U, prevSelected: U) => void,  // 回调函数
  options?: {
    equalityFn?: (a: U, b: U) => boolean;  // 自定义相等性判断
    fireImmediately?: boolean;             // 是否立即触发一次
  }
): () => void
```

### 返回值

所有 `subscribe` 调用都返回一个 **取消订阅函数**，调用后可以停止监听：

```typescript
const unsubscribe = useMyStore.subscribe(
  (state) => state.count,
  (count) => console.log(count),
)

// 取消订阅
unsubscribe()
```

## 在 MapOperation 类中使用（通用示例）

```typescript
// src/map/index.tsx
import { subscribeWithSelector } from 'zustand/middleware'
import { useHeatMapJoinStore } from '@/store'

class MapOperation {
  private static instance: MapOperation

  constructor() {
    // 订阅 multiScaleHeatMap 的变化
    useHeatMapJoinStore.subscribe(
      (state) => state.multiScaleHeatMap,
      (multiScaleHeatMap) => {
        console.log('heatmap 数据发生变化', multiScaleHeatMap)
        // 重新渲染热力图
        this.renderHeatMap()
      },
    )
  }

  // 订阅单个 zoom 级别的数据
  setupZoomLevelSubscription(zoomLevel: number) {
    useHeatMapJoinStore.subscribe(
      (state) => state.multiScaleHeatMap?.[zoomLevel],
      (levelData, prevLevelData) => {
        if (levelData !== prevLevelData) {
          console.log(`${zoomLevel}m 级别的数据发生变化`)
          this.updateHeatMapByZoom(zoomLevel, levelData)
        }
      },
    )
  }
}

export default MapOperation
```

## 带条件的订阅

使用选择器函数进行数据过滤：

```typescript
// 只当 count > 10 时才触发
useMyStore.subscribe(
  (state) => (state.count > 10 ? state.count : null),
  (count) => {
    if (count !== null) {
      console.log('count 超过 10:', count)
    }
  },
)
```

## 在 useEffect 中使用（可选）

虽然在组件中推荐使用 `useShallow` hook，但有时需要在 `useEffect` 中手动订阅：

```typescript
import { useEffect } from 'react'
import { useMyStore } from '@/store'

function MyComponent() {
  useEffect(() => {
    // 订阅 store 变化
    const unsubscribe = useMyStore.subscribe(
      (state) => state.count,
      (count) => {
        console.log('count updated:', count)
        // 执行副作用操作
      }
    )

    // 清理订阅
    return () => unsubscribe()
  }, [])

  return <div>...</div>
}
```

## 注意事项

### ✅ 正确做法

1. **在构造函数或初始化时设置订阅** - 确保只订阅一次
2. **保存取消订阅函数** - 在适当时机清理
3. **使用选择器精确订阅** - 避免不必要的回调
4. **使用 equalityFn 优化性能** - 避免不必要的回调触发

### ❌ 错误做法

```typescript
// 错误：在每次渲染时都创建新订阅
function MyComponent() {
  useMyStore.subscribe((state) => state.count, console.log) // ❌
  return <div>...</div>
}

// 错误：忘记取消订阅导致内存泄漏
useEffect(() => {
  useMyStore.subscribe((state) => state.count, console.log) // ❌ 没有返回清理函数
}, [])

// 错误：在不需要的时候使用 fireImmediately
// 如果只是想获取当前值，直接用 getState() 即可
const count = useMyStore.getState().count // ✅ 正确获取当前值
```

### 🔤 equalityFn 使用技巧

默认的相等性判断是 `Object.is()`，对于对象/数组引用，即使内容相同也会触发回调：

```typescript
// 场景：state.list 是一个数组
// ❌ 问题：即使数组内容相同，引用变化就会触发
useMyStore.subscribe(
  (state) => state.list,
  (list) => console.log('list 变化了') // 每次都会触发
)

// ✅ 解决 1：使用深度比较
import { isEqual } from 'lodash-es'

useMyStore.subscribe(
  (state) => state.list,
  (list) => console.log('list 内容真正变化了才触发')
  { equalityFn: isEqual }
)

// ✅ 解决 2：订阅具体的值
useMyStore.subscribe(
  (state) => state.list.length,
  (length) => console.log('list 长度变化了') // 只有长度变化才触发
)

// ✅ 解决 3：自定义比较逻辑
useMyStore.subscribe(
  (state) => state.filter,
  (filter) => console.log('筛选条件变化了')
  {
    equalityFn: (a, b) =>
      a.category === b.category &&
      a.price === b.price &&
      JSON.stringify(a.tags) === JSON.stringify(b.tags)
  }
)
```

## 与 useShallow 的对比

| 特性 | useShallow (组件内) | subscribeWithSelector (非组件) |
| --- | --- | --- |
| 使用场景 | React 组件内部 | 非 React 环境（工具类、地图操作等） |
| 自动清理 | ✅ 组件卸载时自动清理 | ❌ 需手动调用 unsubscribe() |
| 触发重渲染 | ✅ | ❌ 只执行回调，不触发重渲染 |
| 选择器支持 | ✅ | ✅ |
| equalityFn | ❌ | ✅ 支持自定义相等判断 |
| fireImmediately | ❌ | ✅ 支持立即触发 |
| 推荐度 | 组件内首选 | 非组件场景首选 |

## 最佳实践

1. **组件内优先使用 `useShallow`** - 自动管理生命周期
2. **非组件场景使用 `subscribeWithSelector`** - 如 MapOperation 单例类
3. **及时清理订阅** - 避免内存泄漏
4. **使用精确的选择器** - 减少不必要的回调触发
5. **合理使用 equalityFn** - 对于对象/数组使用深度比较
6. **fireImmediately 用于初始化** - 确保订阅成立时立即执行一次

---

## 类型定义参考

```typescript
// zustand/middleware 类型定义
interface StoreSubscribeWithSelector<T> {
  subscribe: {
    // 形式 1：无选择器（订阅整个状态）
    (listener: (state: T, prevState: T) => void): () => void

    // 形式 2：带选择器（推荐）
    <U>(
      selector: (state: T) => U,
      listener: (selected: U, prevSelected: U) => void,
      options?: {
        equalityFn?: (a: U, b: U) => boolean
        fireImmediately?: boolean
      },
    ): () => void
  }
}
```
