# テスト価値を高めるコード分類とリファクタリング

> 出典: Vladimir Khorikov 著『単体テストの考え方/使い方（Unit Testing: Principles, Practices, and Patterns）』第7章
> クロスリファレンス: [FOUR-PILLARS.md](./FOUR-PILLARS.md) | [THREE-STYLES.md](./THREE-STYLES.md) | [TESTABLE-DESIGN.md](./TESTABLE-DESIGN.md)

---

## 1. 4種類のプロダクション・コード（2軸マトリクス）

すべてのプロダクション・コードは **2つの軸** で分類できる。

| 軸 | 内容 |
|----|------|
| **縦軸** | コードの複雑さ（循環的複雑度）またはドメインにおける重要性 |
| **横軸** | 協力者オブジェクト（可変依存・プロセス外依存）の数 |

```
コードの複雑さ /
ドメイン重要性
        ↑
  高 ──┼─────────────────────────────────────
        │ ② ドメインモデル/    │ ① 過度に複雑な │
        │    アルゴリズム      │    コード      │
        │  ★ テストのROI最高  │  ⚡ 要分割     │
  低 ──┼─────────────────────────────────────
        │ ③ 取るに足らない     │ ④ コントローラ │
        │    コード            │  ✓ 統合テスト  │
        │  ✕ テスト不要       │               │
        └──────────────────────┴───────────────→
                              少              多
                        協力者オブジェクトの数
```

### 各象限の詳細

| ゾーン | 特徴 | テスト戦略 |
|-------|------|----------|
| ② **ドメインモデル/アルゴリズム** | 複雑・重要。協力者が少ない（理想ゼロ） | **単体テスト**最優先。カバレッジ100% |
| ③ **取るに足らないコード** | 複雑さなし。協力者も少ない。コンストラクタ等 | テスト不要（退行保護がほぼない） |
| ④ **コントローラ** | 単純だが協力者が多い（DB・外部API） | **統合テスト**で検証 |
| ① **過度に複雑なコード** | 複雑かつ協力者も多い「太ったコントローラ」 | **リファクタリング必須**。そのままテストしない |

> **TIP**: コードが複雑・重要になるほど協力者オブジェクトの数を減らさなければならない

### 循環的複雑度

```
循環的複雑度 = 1 + 分岐の数
```

注意: ライブラリ内部の型変換・配列アクセスにも隠れた分岐が存在する。外見上シンプルでもテスト価値を持つ場合がある。

---

## 2. Humble Object パターン

### 概念

過度に複雑なコード（ロジック＋テスト困難な依存の混在）を分割する設計パターン。

```
 【分割前: 過度に複雑なコード】
  ロジック ←────→ テスト困難な依存（DB/非同期/UI）
         混在している

 【分割後: Humble Object パターン適用】
  質素なオブジェクト（Humble Object）= コントローラ
    └─ テスト困難な依存を担当（DB・外部API・非同期）
    └─ ロジックはほぼ持たない → テスト不要

  ドメインモデル（抽出されたロジック）
    └─ 協力者オブジェクトなし → 単体テスト容易
```

### アーキテクチャとの関係

| アーキテクチャ | Humble Object の位置 | ロジックの位置 |
|--------------|---------------------|-------------|
| ヘキサゴナル | アプリケーションサービス層 | ドメイン層 |
| 関数型 | 可変殻（mutable shell） | 関数的核（functional core） |
| MVP / MVC | Presenter / Controller | Model |
| DDD 集約 | 集約間の調整 | 集約内ロジック |

> 関数型アーキテクチャの関数的核はドメインモデルゾーン（②）の極致。協力者オブジェクトが完全にゼロになる

---

## 3. リファクタリング実例（ユーザ管理システム）

### 初期実装の問題

```typescript
// ❌ Active Recordパターン: ドメインクラスがDB・外部APIと直結
class User {
  changeEmail(userId: number, newEmail: string): void {
    const data = Database.getUserById(userId)     // プロセス外依存①
    const companyData = Database.getCompany()     // プロセス外依存②
    // ...ビジネスロジック...
    Database.saveUser(this)                        // DB書き込み
    MessageBus.sendEmailChangedMessage(userId, newEmail) // 外部通知
  }
}
// → ドメイン重要性高 + 協力者多 = 過度に複雑なコード（①のゾーン）
```

### Step 1: アプリケーションサービス層の導入

```typescript
// ✅ コントローラ（Humble Object）: 連携の調整のみ
class UserController {
  changeEmail(userId: number, newEmail: string): void {
    const userData = this.database.getUserById(userId)
    const companyData = this.database.getCompany()
    user.changeEmail(newEmail, companyDomainName, numberOfEmployees)
    this.database.saveUser(user)
    this.messageBus.sendEmailChangedMessage(userId, newEmail)
  }
}

// ✅ ドメインモデル: 協力者なし → 単体テスト容易
class User {
  changeEmail(newEmail: string, companyDomain: string, numEmployees: number): number {
    // 純粋なビジネスロジックのみ
    if (this.email === newEmail) return numEmployees
    const newType = newEmail.split('@')[1] === companyDomain
      ? UserType.Employee : UserType.Customer
    if (this.type !== newType) numEmployees += newType === UserType.Employee ? 1 : -1
    this.email = newEmail
    this.type = newType
    return numEmployees
  }
}
```

### Step 2: Companyクラスの導入（責務の明確化）

```typescript
// ✅ 会社ロジックを専用クラスにカプセル化
class Company {
  constructor(readonly domainName: string, public numberOfEmployees: number) {}

  isEmailCorporate(email: string): boolean {
    return email.split('@')[1] === this.domainName
  }

  changeNumberOfEmployees(delta: number): void {
    if (this.numberOfEmployees + delta < 0) throw new Error('従業員数はマイナス不可')
    this.numberOfEmployees += delta
  }
}

// ✅ Userクラス: Companyを唯一の協力者として持つ（ドメインモデルゾーン②）
class User {
  changeEmail(newEmail: string, company: Company): void {
    if (this.email === newEmail) return
    const newType = company.isEmailCorporate(newEmail)
      ? UserType.Employee : UserType.Customer
    if (this.type !== newType) {
      company.changeNumberOfEmployees(newType === UserType.Employee ? 1 : -1)
    }
    this.email = newEmail
    this.type = newType
  }
}
```

### Vitest テストコード

```typescript
describe('User.changeEmail', () => {
  it('顧客から従業員にメールアドレスを変更する', () => {
    const company = new Company('mycorp.com', 1)
    const user = new User(1, 'user@gmail.com', UserType.Customer)

    user.changeEmail('new@mycorp.com', company)

    expect(company.numberOfEmployees).toBe(2)
    expect(user.email).toBe('new@mycorp.com')
    expect(user.type).toBe(UserType.Employee)
  })
})

describe('Company.isEmailCorporate', () => {
  it.each([
    ['mycorp.com', 'email@mycorp.com', true],
    ['mycorp.com', 'email@gmail.com', false],
  ])('ドメイン %s のとき %s は %s', (domain, email, expected) => {
    const actual = new Company(domain, 0).isEmailCorporate(email)
    expect(actual).toBe(expected)
  })
})
```

### 最終的なコード分類

| クラス / メソッド | 複雑さ | 協力者数 | 分類 | テスト |
|----------------|-------|---------|------|-------|
| `User.changeEmail` | 高 | 少（Company） | ドメインモデル② | 単体テスト |
| `Company.isEmailCorporate` | 高 | なし | ドメインモデル② | 単体テスト |
| `UserFactory.create` | 中（隠れた分岐） | なし | アルゴリズム② | 単体テスト |
| `Userコンストラクタ` | 低 | なし | 取るに足らない③ | 不要 |
| `UserController.changeEmail` | 低 | 多 | コントローラ④ | 統合テスト |

---

## 4. コントローラの条件付きロジック対処

### 3つのトレードオフ

| 選択肢 | テストしやすさ | 簡潔さ | パフォーマンス |
|-------|-------------|-------|-------------|
| ①読み書きを最初/最後に集約 | ✓ | ✓ | ✗（不要なDB呼出） |
| ②プロセス外依存をDMに注入 | ✗（DM汚染） | ✓ | ✓ |
| ③決定過程を細かく分割 | ✓ | ✗（分岐が増える） | ✓ |

**推奨**: ③を選びつつ、複雑さを管理可能なレベルに抑える

### CanExecute/Execute パターン（確認後実行）

ドメインロジックがコントローラに流出することを防ぐ:

```typescript
class User {
  // CanExecute: 事前条件の確認
  canChangeEmail(): string | null {
    return this.isEmailConfirmed ? 'メールアドレス確定済みのため変更不可' : null
  }

  // Execute: 内部で再確認して実行（カプセル化を保護）
  changeEmail(newEmail: string, company: Company): void {
    if (this.canChangeEmail() !== null) throw new Error('変更不可')
    // ...
  }
}

// コントローラはビジネスルールの詳細を知らなくてよい
class UserController {
  changeEmail(userId: number, newEmail: string): string {
    const user = UserFactory.create(this.database.getUserById(userId))
    const error = user.canChangeEmail()  // CanExecute
    if (error !== null) return error     // 早期リターン（DB呼出を回避）

    const company = CompanyFactory.create(this.database.getCompany())
    user.changeEmail(newEmail, company)  // Execute
    // ...
    return 'OK'
  }
}
```

### ドメインイベントによる状態追跡

外部通知のタイミングをドメインモデル自身が管理する:

```typescript
class EmailChangedEvent {
  constructor(readonly userId: number, readonly newEmail: string) {}
}

class User {
  emailChangedEvents: EmailChangedEvent[] = []

  changeEmail(newEmail: string, company: Company): void {
    if (this.email === newEmail) return  // 変更なし → イベント発行しない
    // ...ビジネスロジック...
    this.emailChangedEvents.push(new EmailChangedEvent(this.userId, newEmail))
  }
}

// テスト: プロセス外依存のモックなしでイベント発行を検証
it('メールアドレス変更時にドメインイベントが発行される', () => {
  const company = new Company('mycorp.com', 1)
  const user = new User(1, 'user@mycorp.com', UserType.Employee, false)

  user.changeEmail('new@gmail.com', company)

  expect(user.emailChangedEvents).toHaveLength(1)
  expect(user.emailChangedEvents[0].newEmail).toBe('new@gmail.com')
})
```

---

## 5. コードの深さ vs コードの広さ

```
コードの深さ（depth）= 複雑さ + ドメイン重要性  →  ドメインモデルが持つべき性質
コードの広さ（width）= 協力者オブジェクトの数   →  コントローラが持つべき性質
```

**絶対ルール**: 深さと広さを同時に持たせてはならない。

### 事前条件のテスト判断基準

| 事前条件の種類 | テスト | 理由 |
|-------------|-------|------|
| ドメインの不変条件（例: 従業員数 >= 0） | する | ドメイン重要性が高い |
| インフラ的ガード（例: 配列長 >= 3） | しない | ドメイン重要性がない |

---

## まとめ

- **何をテストするか**: ドメインモデル/アルゴリズム（②）を単体テストで徹底的に検証する
- **何をテストしないか**: 取るに足らないコード（③）はテスト不要
- **過度に複雑なコードへの対処**: まずリファクタリングしてから②と④に分割
- **100%カバレッジは目標ではない**: 価値のあるテストだけでスイートを構築すること

> 質の悪いテストケースを作るくらいなら、まったく作らないほうがよい。
