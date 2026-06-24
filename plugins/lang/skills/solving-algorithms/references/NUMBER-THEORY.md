# 整数論リファレンス

競技プログラミングにおける整数論の基礎アルゴリズム。
素数判定・GCD/LCM・べき乗の3本柱を中心に構成する。

---

## 1. 素数判定

### 1.1 試し割り法

**計算量**: O(√n)

合成数 n は必ず √n 以下の素因数を持つ。2〜√n の範囲だけ試せばよい。

```
isPrime(x):
  if x < 2: return false
  if x == 2: return true
  if x % 2 == 0: return false
  i = 3
  while i * i <= x:
    if x % i == 0: return false
    i += 2       // 奇数のみ試す
  return true
```

**応用**: 単一の数の素数判定・素因数分解の前処理

---

### 1.2 エラトステネスの篩

**計算量**: O(N log log N)  **空間**: O(N)

N 以下の全素数を一括列挙する。小さい素数から順に倍数を消去する。

```
sieve(N):
  isPrime[0..N] = true
  isPrime[0] = isPrime[1] = false
  for i = 2 to sqrt(N):
    if isPrime[i]:
      j = i * i         // i^2 未満は既に消去済み
      while j <= N:
        isPrime[j] = false
        j += i
```

**応用**: 素数カウント・複数クエリへの使い回し・素因数分解の前処理

---

### 1.3 素因数分解

**計算量**: O(√n)

試し割り法の応用。割り切れる数を繰り返し除算し、残余が素因数となる。

```
factorize(x):
  factors = []
  for i = 2 while i * i <= x:
    while x % i == 0:
      factors.append(i)
      x /= i
  if x > 1: factors.append(x)   // 残余は大きな素因数
  return factors
```

---

## 2. 最大公約数（GCD）と最小公倍数（LCM）

### 2.1 ユークリッドの互除法

**計算量**: O(log min(a, b))

定理: `gcd(a, b) = gcd(b, a % b)`（b = 0 のとき a が答え）

```
gcd(x, y):
  while y > 0:
    r = x % y
    x = y
    y = r
  return x
```

余りは指数的に減少するため O(log b) で収束する。

---

### 2.2 最小公倍数（LCM）

**計算量**: O(log min(a, b))

```
lcm(x, y):
  return (x / gcd(x, y)) * y   // 先に割ることでオーバーフロー対策
```

複数整数の LCM は `lcm(lcm(a, b), c)` のように2つずつ適用する。

---

### 2.3 拡張ユークリッドの互除法

**計算量**: O(log min(a, b))

`ax + by = gcd(a, b)` を満たす整数解 (x, y) を求める。

```
extgcd(a, b):
  if b == 0: return (a, x=1, y=0)
  (g, x1, y1) = extgcd(b, a % b)
  return (g, y1, x1 - (a / b) * y1)
```

**応用**:
- `ax ≡ 1 (mod m)` の乗法逆元（m が素数でない場合）
- 線形合同式 `ax ≡ c (mod m)` の解
- 中国剰余定理（CRT）

---

## 3. べき乗

### 3.1 繰り返し二乗法（Binary Exponentiation）

**計算量**: O(log n)（素朴な方法は O(n)）

`x^n = (x^2)^(n/2)` という性質を再帰的に利用する。

```
pow(x, n):
  if n == 0: return 1
  res = pow(x * x, n / 2)
  if n % 2 == 1: res *= x
  return res
```

---

### 3.2 mod 付きべき乗

**計算量**: O(log n)

`m^n mod M` を求める場合、乗算ごとに mod を挟む。

```
modpow(x, n, M):
  if n == 0: return 1
  res = modpow(x * x % M, n / 2, M)
  if n % 2 == 1: res = res * x % M
  return res
```

**mod 演算の性質**:
- `(a + b) % M = ((a % M) + (b % M)) % M`
- `(a * b) % M = ((a % M) * (b % M)) % M`
- 除算は逆元が必要（フェルマーの小定理または拡張ユークリッド）

---

## 4. 計算量まとめ

| アルゴリズム | 計算量 | 空間 |
|---|---|---|
| 試し割り（素数判定・素因数分解） | O(√n) | O(1) |
| エラトステネスの篩 | O(N log log N) | O(N) |
| ユークリッドの互除法（GCD） | O(log min(a,b)) | O(1) |
| LCM | O(log min(a,b)) | O(1) |
| 拡張ユークリッド | O(log min(a,b)) | O(log n) |
| 繰り返し二乗法 | O(log n) | O(log n) |

---

## 5. 典型的な応用場面

| テーマ | 使うアルゴリズム | 具体例 |
|---|---|---|
| 素数判定・列挙 | 試し割り・篩 | 素数カウント、素因数分解 |
| 分数・約数問題 | GCD / LCM | 分数の約分、周期・タイミング問題 |
| 合同式・逆元 | 拡張ユークリッド | `ax ≡ 1 (mod m)`、CRT |
| 大きなべき乗 | 繰り返し二乗法 | nCr mod p、行列累乗、線形漸化式 |
