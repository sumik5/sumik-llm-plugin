# 数学シンボルテーブル

LaTeX数学環境で使用可能なシンボルの包括的リファレンス。

---

## ヘブライ文字

| コマンド | 出力 | 説明 |
|---------|------|------|
| `\aleph` | ℵ | アレフ |
| `\beth` | ℶ | ベート |
| `\daleth` | ℸ | ダレット |
| `\gimel` | ג | ギメル |

---

## ギリシャ文字

### 小文字

| コマンド | 出力 | コマンド | 出力 | コマンド | 出力 |
|---------|------|---------|------|---------|------|
| `\alpha` | α | `\iota` | ι | `\sigma` | σ |
| `\beta` | β | `\kappa` | κ | `\tau` | τ |
| `\gamma` | γ | `\lambda` | λ | `\upsilon` | υ |
| `\delta` | δ | `\mu` | μ | `\phi` | ϕ |
| `\epsilon` | ϵ | `\nu` | ν | `\chi` | χ |
| `\zeta` | ζ | `\xi` | ξ | `\psi` | ψ |
| `\eta` | η | `\pi` | π | `\omega` | ω |
| `\theta` | θ | `\rho` | ρ | | |

### バリアント（小文字）

| コマンド | 出力 | コマンド | 出力 |
|---------|------|---------|------|
| `\varepsilon` | ε | `\varpi` | ϖ |
| `\vartheta` | ϑ | `\varrho` | ϱ |
| `\varsigma` | ς | `\varphi` | φ |
| `\digamma` | ϝ | `\varkappa` | ϰ |

### 大文字

| コマンド | 出力 | コマンド | 出力 | コマンド | 出力 |
|---------|------|---------|------|---------|------|
| `\Gamma` | Γ | `\Xi` | Ξ | `\Phi` | Φ |
| `\Delta` | Δ | `\Pi` | Π | `\Psi` | Ψ |
| `\Theta` | Θ | `\Sigma` | Σ | `\Omega` | Ω |
| `\Lambda` | Λ | `\Upsilon` | Υ | | |

### バリアント（大文字）

| コマンド | 出力 | コマンド | 出力 | コマンド | 出力 |
|---------|------|---------|------|---------|------|
| `\varGamma` | Γ | `\varXi` | Ξ | `\varPhi` | Φ |
| `\varDelta` | Δ | `\varPi` | Π | `\varPsi` | Ψ |
| `\varTheta` | Θ | `\varSigma` | Σ | `\varOmega` | Ω |
| `\varLambda` | Λ | `\varUpsilon` | Υ | | |

---

## 二項関係

### 基本二項関係

| コマンド | 出力 | コマンド | 出力 |
|---------|------|---------|------|
| `<` | < | `>` | > |
| `=` | = | `:` | : |
| `\in` | ∈ | `\ni` / `\owns` | ∋ |
| `\leq` / `\le` | ≤ | `\geq` / `\ge` | ≥ |
| `\ll` | ≪ | `\gg` | ≫ |
| `\prec` | ≺ | `\succ` | ≻ |
| `\preceq` | ≼ | `\succeq` | ≽ |
| `\sim` | ∼ | `\approx` | ≈ |
| `\simeq` | ≃ | `\cong` | ≅ |
| `\equiv` | ≡ | `\doteq` | ≐ |
| `\subset` | ⊂ | `\supset` | ⊃ |
| `\subseteq` | ⊆ | `\supseteq` | ⊇ |
| `\sqsubseteq` | ⊑ | `\sqsupseteq` | ⊒ |
| `\smile` | ⌣ | `\frown` | ⌢ |
| `\perp` | ⊥ | `\models` | ⊨ |
| `\mid` | &#124; | `\parallel` | ∥ |
| `\vdash` | ⊢ | `\dashv` | ⊣ |
| `\propto` | ∝ | `\asymp` | ≍ |
| `\bowtie` | ⋈ | | |
| `\sqsubset` | ⊏ | `\sqsupset` | ⊐ |
| `\Join` | ⋈ | | |

**注意**: `\colon` を関数定義で使用（例: `f \colon x \to x^2` → f : x → x²）

### 追加二項関係

| コマンド | 出力 | コマンド | 出力 |
|---------|------|---------|------|
| `\leqq` | ≦ | `\geqq` | ≧ |
| `\leqslant` | ⩽ | `\geqslant` | ⩾ |
| `\eqslantless` | ⪕ | `\eqslantgtr` | ⪖ |
| `\lesssim` | ≲ | `\gtrsim` | ≳ |
| `\lessapprox` | ⪅ | `\gtrapprox` | ⪆ |
| `\approxeq` | ≊ | | |
| `\lessdot` | ⋖ | `\gtrdot` | ⋗ |
| `\lll` | ⋘ | `\ggg` | ⋙ |
| `\lessgtr` | ≶ | `\gtrless` | ≷ |
| `\lesseqgtr` | ⋚ | `\gtreqless` | ⋛ |
| `\lesseqqgtr` | ⪋ | `\gtreqqless` | ⪌ |
| `\doteqdot` | ≑ | `\eqcirc` | ≖ |
| `\circeq` | ≗ | `\triangleq` | ≜ |
| `\risingdotseq` | ≓ | `\fallingdotseq` | ≒ |
| `\backsim` | ∽ | `\thicksim` | ∼ |
| `\backsimeq` | ⋍ | `\thickapprox` | ≈ |
| `\preccurlyeq` | ≼ | `\succcurlyeq` | ≽ |
| `\curlyeqprec` | ⋞ | `\curlyeqsucc` | ⋟ |
| `\precsim` | ≾ | `\succsim` | ≿ |
| `\precapprox` | ⪷ | `\succapprox` | ⪸ |
| `\subseteqq` | ⫅ | `\supseteqq` | ⫆ |
| `\Subset` | ⋐ | `\Supset` | ⋑ |
| `\vartriangleleft` | ⊲ | `\vartriangleright` | ⊳ |
| `\trianglelefteq` | ⊴ | `\trianglerighteq` | ⊵ |
| `\vDash` | ⊨ | `\Vdash` | ⊩ |
| `\Vvdash` | ⊪ | | |
| `\smallsmile` | ⌣ | `\smallfrown` | ⌢ |
| `\shortmid` | ∣ | `\shortparallel` | ∥ |
| `\bumpeq` | ≏ | `\Bumpeq` | ≎ |
| `\between` | ≬ | `\pitchfork` | ⋔ |
| `\varpropto` | ∝ | `\backepsilon` | ϶ |
| `\blacktriangleleft` | ◀ | `\blacktriangleright` | ▶ |
| `\therefore` | ∴ | `\because` | ∵ |

### 否定二項関係

| コマンド | 出力 | コマンド | 出力 |
|---------|------|---------|------|
| `\neq` / `\ne` | ≠ | `\notin` | ∉ |
| `\nless` | ≮ | `\ngtr` | ≯ |
| `\nleq` | ≰ | `\ngeq` | ≱ |
| `\nleqslant` | ⩽̸ | `\ngeqslant` | ⩾̸ |
| `\nleqq` | ≦̸ | `\ngeqq` | ≧̸ |
| `\lneq` | ⪇ | `\gneq` | ⪈ |
| `\lneqq` | ≨ | `\gneqq` | ≩ |
| `\lvertneqq` | ≨︀ | `\gvertneqq` | ≩︀ |
| `\lnsim` | ⋦ | `\gnsim` | ⋧ |
| `\lnapprox` | ⪉ | `\gnapprox` | ⪊ |
| `\nprec` | ⊀ | `\nsucc` | ⊁ |
| `\npreceq` | ⋠ | `\nsucceq` | ⋡ |
| `\precneqq` | ⪵ | `\succneqq` | ⪶ |
| `\precnsim` | ⋨ | `\succnsim` | ⋩ |
| `\precnapprox` | ⪹ | `\succnapprox` | ⪺ |
| `\nsim` | ≁ | `\ncong` | ≇ |
| `\nshortmid` | ∤ | `\nshortparallel` | ∦ |
| `\nmid` | ∤ | `\nparallel` | ∦ |
| `\nvdash` | ⊬ | `\nvDash` | ⊭ |
| `\nVdash` | ⊮ | `\nVDash` | ⊯ |
| `\ntriangleleft` | ⋪ | `\ntriangleright` | ⋫ |
| `\ntrianglelefteq` | ⋬ | `\ntrianglerighteq` | ⋭ |
| `\nsubseteq` | ⊈ | `\nsupseteq` | ⊉ |
| `\nsubseteqq` | ⫅̸ | `\nsupseteqq` | ⫆̸ |
| `\subsetneq` | ⊊ | `\supsetneq` | ⊋ |
| `\varsubsetneq` | ⊊︀ | `\varsupsetneq` | ⊋︀ |
| `\subsetneqq` | ⫋ | `\supsetneqq` | ⫌ |
| `\varsubsetneqq` | ⫋︀ | `\varsupsetneqq` | ⫌︀ |

---

## 二項演算

| コマンド | 出力 | コマンド | 出力 |
|---------|------|---------|------|
| `+` | + | `-` | − |
| `\pm` | ± | `\mp` | ∓ |
| `\times` | × | `\cdot` | · |
| `\circ` | ∘ | `\bigcirc` | ◯ |
| `\div` | ÷ | `\bmod` | mod |
| `\cap` | ∩ | `\cup` | ∪ |
| `\sqcap` | ⊓ | `\sqcup` | ⊔ |
| `\wedge` / `\land` | ∧ | `\vee` / `\lor` | ∨ |
| `\triangleleft` | ◁ | `\triangleright` | ▷ |
| `\bigtriangleup` | △ | `\bigtriangledown` | ▽ |
| `\oplus` | ⊕ | `\ominus` | ⊖ |
| `\otimes` | ⊗ | `\oslash` | ⊘ |
| `\odot` | ⊙ | `\bullet` | • |
| `\dagger` | † | `\ddagger` | ‡ |
| `\setminus` | \ | `\smallsetminus` | ∖ |
| `\wr` | ≀ | `\amalg` | ⨿ |
| `\ast` | ∗ | `\star` | ⋆ |
| `\diamond` | ⋄ | | |
| `\lhd` | ⊲ | `\rhd` | ⊳ |
| `\unlhd` | ⊴ | `\unrhd` | ⊵ |
| `\dotplus` | ∔ | `\centerdot` | · |
| `\ltimes` | ⋉ | `\rtimes` | ⋊ |
| `\leftthreetimes` | ⋋ | `\rightthreetimes` | ⋌ |
| `\circleddash` | ⊝ | `\uplus` | ⊎ |
| `\barwedge` | ⊼ | `\doublebarwedge` | ⩞ |
| `\curlywedge` | ⋏ | `\curlyvee` | ⋎ |
| `\veebar` | ⊻ | `\intercal` | ⊺ |
| `\doublecap` / `\Cap` | ⋒ | `\doublecup` / `\Cup` | ⋓ |
| `\circledast` | ⊛ | `\circledcirc` | ⊚ |
| `\boxminus` | ⊟ | `\boxtimes` | ⊠ |
| `\boxdot` | ⊡ | `\boxplus` | ⊞ |
| `\divideontimes` | ⋇ | `\vartriangle` | △ |
| `\And` | & | | |

---

## 矢印

| コマンド | 出力 | コマンド | 出力 |
|---------|------|---------|------|
| `\leftarrow` | ← | `\rightarrow` / `\to` | → |
| `\longleftarrow` | ←− | `\longrightarrow` | −→ |
| `\Leftarrow` | ⇐ | `\Rightarrow` | ⇒ |
| `\Longleftarrow` | ⇐= | `\Longrightarrow` | =⇒ |
| `\leftrightarrow` | ↔ | `\longleftrightarrow` | ←→ |
| `\Leftrightarrow` | ⇔ | `\Longleftrightarrow` | ⇐⇒ |
| `\uparrow` | ↑ | `\downarrow` | ↓ |
| `\Uparrow` | ⇑ | `\Downarrow` | ⇓ |
| `\updownarrow` | ↕ | `\Updownarrow` | ⇕ |
| `\nearrow` | ↗ | `\searrow` | ↘ |
| `\swarrow` | ↙ | `\nwarrow` | ↖ |
| `\iff` | ⇔ | `\mapstochar` | ↦ |
| `\mapsto` | ↦ | `\longmapsto` | ⟼ |
| `\hookleftarrow` | ↩ | `\hookrightarrow` | ↪ |
| `\leftharpoonup` | ↼ | `\rightharpoonup` | ⇀ |
| `\leftharpoondown` | ↽ | `\rightharpoondown` | ⇁ |
| `\leadsto` | ⇝ | | |
| `\leftleftarrows` | ⇇ | `\rightrightarrows` | ⇉ |
| `\leftrightarrows` | ⇆ | `\rightleftarrows` | ⇄ |
| `\Lleftarrow` | ⇚ | `\Rrightarrow` | ⇛ |
| `\twoheadleftarrow` | ↞ | `\twoheadrightarrow` | ↠ |
| `\leftarrowtail` | ↢ | `\rightarrowtail` | ↣ |
| `\looparrowleft` | ↫ | `\looparrowright` | ↬ |
| `\upuparrows` | ⇈ | `\downdownarrows` | ⇊ |
| `\upharpoonleft` | ↿ | `\upharpoonright` | ↾ |
| `\downharpoonleft` | ⇃ | `\downharpoonright` | ⇂ |
| `\leftrightsquigarrow` | ↭ | `\rightsquigarrow` | ⇝ |
| `\multimap` | ⊸ | | |
| `\nleftarrow` | ↚ | `\nrightarrow` | ↛ |
| `\nLeftarrow` | ⇍ | `\nRightarrow` | ⇏ |
| `\nleftrightarrow` | ↮ | `\nLeftrightarrow` | ⇎ |
| `\dashleftarrow` | ⇠ | `\dashrightarrow` | ⇢ |
| `\curvearrowleft` | ↶ | `\curvearrowright` | ↷ |
| `\circlearrowleft` | ↺ | `\circlearrowright` | ↻ |
| `\leftrightharpoons` | ⇋ | `\rightleftharpoons` | ⇌ |
| `\Lsh` | ↰ | `\Rsh` | ↱ |

---

## その他のシンボル

| コマンド | 出力 | コマンド | 出力 |
|---------|------|---------|------|
| `\hbar` | ℏ | `\ell` | ℓ |
| `\imath` | ı | `\jmath` | ȷ |
| `\wp` | ℘ | `\partial` | ∂ |
| `\Im` | ℑ | `\Re` | ℜ |
| `\infty` | ∞ | `\prime` | ′ |
| `\emptyset` | ∅ | `\varnothing` | ∅ |
| `\forall` | ∀ | `\exists` | ∃ |
| `\smallint` | ∫ | `\triangle` | △ |
| `\top` | ⊤ | `\bot` | ⊥ |
| `\P` | ¶ | `\S` | § |
| `\dag` | † | `\ddag` | ‡ |
| `\flat` | ♭ | `\natural` | ♮ |
| `\sharp` | ♯ | `\angle` | ∠ |
| `\clubsuit` | ♣ | `\diamondsuit` | ♢ |
| `\heartsuit` | ♡ | `\spadesuit` | ♠ |
| `\surd` | √ | `\nabla` | ∇ |
| `\pounds` | £ | `\neg` / `\lnot` | ¬ |
| `\Box` | □ | `\Diamond` | ◇ |
| `\mho` | ℧ | | |
| `\hslash` | ℏ | `\complement` | ∁ |
| `\backprime` | ‵ | `\nexists` | ∄ |
| `\Bbbk` | 𝕜 | | |
| `\diagup` | ╱ | `\diagdown` | ╲ |
| `\blacktriangle` | ▲ | `\blacktriangledown` | ▼ |
| `\triangledown` | ▽ | `\eth` | ð |
| `\square` | □ | `\blacksquare` | ■ |
| `\lozenge` | ◊ | `\blacklozenge` | ♦ |
| `\measuredangle` | ∡ | `\sphericalangle` | ∢ |
| `\circledS` | Ⓢ | `\bigstar` | ★ |
| `\Finv` | Ⅎ | `\Game` | ⅁ |

---

## デリミタ

| 名称 | コマンド | 出力 |
|------|---------|------|
| 左丸括弧 | `(` | ( |
| 右丸括弧 | `)` | ) |
| 左角括弧 | `[` / `\lbrack` | [ |
| 右角括弧 | `]` / `\rbrack` | ] |
| 左波括弧 | `\{` / `\lbrace` | { |
| 右波括弧 | `\}` / `\rbrace` | } |
| バックスラッシュ | `\backslash` | \ |
| スラッシュ | `/` | / |
| 左角度括弧 | `\langle` | ⟨ |
| 右角度括弧 | `\rangle` | ⟩ |
| 縦線 | `|` / `\vert` | &#124; |
| 二重縦線 | `\|` / `\Vert` | ∥ |
| 左フロア | `\lfloor` | ⌊ |
| 右フロア | `\rfloor` | ⌋ |
| 左シーリング | `\lceil` | ⌈ |
| 右シーリング | `\rceil` | ⌉ |
| 上矢印 | `\uparrow` | ↑ |
| 二重上矢印 | `\Uparrow` | ⇑ |
| 下矢印 | `\downarrow` | ↓ |
| 二重下矢印 | `\Downarrow` | ⇓ |
| 上下矢印 | `\updownarrow` | ↕ |
| 二重上下矢印 | `\Updownarrow` | ⇕ |
| 左上コーナー | `\ulcorner` | ⌜ |
| 右上コーナー | `\urcorner` | ⌝ |
| 左下コーナー | `\llcorner` | ⌞ |
| 右下コーナー | `\lrcorner` | ⌟ |

**注意**: デリミタは `\left` と `\right` と組み合わせてサイズ調整可能。

---

## 演算子

### 関数名演算子（極限なし）

| コマンド | 出力 | コマンド | 出力 | コマンド | 出力 | コマンド | 出力 |
|---------|------|---------|------|---------|------|---------|------|
| `\arccos` | arccos | `\cot` | cot | `\hom` | hom | `\sin` | sin |
| `\arcsin` | arcsin | `\coth` | coth | `\ker` | ker | `\sinh` | sinh |
| `\arctan` | arctan | `\csc` | csc | `\lg` | lg | `\tan` | tan |
| `\arg` | arg | `\deg` | deg | `\ln` | ln | `\tanh` | tanh |
| `\cos` | cos | `\dim` | dim | `\log` | log | | |
| `\cosh` | cosh | `\exp` | exp | `\sec` | sec | | |

### 極限付き演算子

| コマンド | 出力 | コマンド | 出力 |
|---------|------|---------|------|
| `\det` | det | `\limsup` | lim sup |
| `\gcd` | gcd | `\max` | max |
| `\inf` | inf | `\min` | min |
| `\lim` | lim | `\Pr` | Pr |
| `\liminf` | lim inf | `\sup` | sup |
| `\injlim` | inj lim | `\projlim` | proj lim |
| `\varliminf` | lim | `\varlimsup` | lim |
| `\varinjlim` | lim | `\varprojlim` | lim |

### 大型演算子

| コマンド | インライン | ディスプレイ |
|---------|----------|------------|
| `\int_{a}^{b}` | ∫ᵇₐ | ∫ᵇ<br>ₐ |
| `\oint_{a}^{b}` | ∮ᵇₐ | ∮ᵇ<br>ₐ |
| `\iint_{a}^{b}` | ∬ᵇₐ | ∬ᵇ<br>ₐ |
| `\iiint_{a}^{b}` | ∭ᵇₐ | ∭ᵇ<br>ₐ |
| `\iiiint_{a}^{b}` | ⨌ᵇₐ | ⨌ᵇ<br>ₐ |
| `\idotsint_{a}^{b}` | ∫⋯∫ᵇₐ | ∫⋯∫ᵇ<br>ₐ |
| `\prod_{i=1}^{n}` | ∏ⁿᵢ₌₁ | ∏<br>ⁿ<br>ᵢ₌₁ |
| `\coprod_{i=1}^{n}` | ∐ⁿᵢ₌₁ | ∐<br>ⁿ<br>ᵢ₌₁ |
| `\bigcap_{i=1}^{n}` | ⋂ⁿᵢ₌₁ | ⋂<br>ⁿ<br>ᵢ₌₁ |
| `\bigcup_{i=1}^{n}` | ⋃ⁿᵢ₌₁ | ⋃<br>ⁿ<br>ᵢ₌₁ |
| `\bigwedge_{i=1}^{n}` | ⋀ⁿᵢ₌₁ | ⋀<br>ⁿ<br>ᵢ₌₁ |
| `\bigvee_{i=1}^{n}` | ⋁ⁿᵢ₌₁ | ⋁<br>ⁿ<br>ᵢ₌₁ |
| `\bigsqcup_{i=1}^{n}` | ⊔ⁿᵢ₌₁ | ⊔<br>ⁿ<br>ᵢ₌₁ |
| `\biguplus_{i=1}^{n}` | ⨄ⁿᵢ₌₁ | ⨄<br>ⁿ<br>ᵢ₌₁ |
| `\bigotimes_{i=1}^{n}` | ⨂ⁿᵢ₌₁ | ⨂<br>ⁿ<br>ᵢ₌₁ |
| `\bigoplus_{i=1}^{n}` | ⨁ⁿᵢ₌₁ | ⨁<br>ⁿ<br>ᵢ₌₁ |
| `\bigodot_{i=1}^{n}` | ⨀ⁿᵢ₌₁ | ⨀<br>ⁿ<br>ᵢ₌₁ |
| `\sum_{i=1}^{n}` | ∑ⁿᵢ₌₁ | ∑<br>ⁿ<br>ᵢ₌₁ |

**注意**: ディスプレイスタイルでは上下に添字が配置され、インラインスタイルでは右肩・右下に配置される。

---

## 数学アクセント

| コマンド | 出力 | コマンド | 出力 |
|---------|------|---------|------|
| `\acute{a}` | á | | |
| `\bar{a}` | ā | | |
| `\breve{a}` | ă | `\spbreve` | ˘ (amsxtra) |
| `\check{a}` | ǎ | `\spcheck` | ˇ (amsxtra) |
| `\dot{a}` | ȧ | `\spdot` | ˙ (amsxtra) |
| `\ddot{a}` | ä | `\spddot` | ¨ (amsxtra) |
| `\dddot{a}` | a⃛ | `\spdddot` | ⃛ (amsxtra) |
| `\ddddot{a}` | a⃜ | | |
| `\grave{a}` | à | | |
| `\hat{a}` | â | | |
| `\widehat{a}` | â̂ | `\sphat` | ˆ (amsxtra) |
| `\mathring{a}` | å | | |
| `\tilde{a}` | ã | | |
| `\widetilde{a}` | ã̃ | `\sptilde` | ˜ (amsxtra) |
| `\vec{a}` | a⃗ | | |

**注意**: `amsxtra` パッケージが必要なコマンドには (amsxtra) と注記。

---

## 数学フォント

| コマンド | 出力 | 説明 |
|---------|------|------|
| `\mathbf{A}` | **A** | 太字 |
| `\mathcal{A}` | 𝒜 | カリグラフィック |
| `\mathit{A}` | 𝐴 | イタリック |
| `\mathnormal{A}` | 𝐴 | ノーマル（デフォルト） |
| `\mathrm{A}` | A | ローマン |
| `\mathsf{A}` | 𝖠 | サンセリフ |
| `\mathtt{A}` | 𝙰 | タイプライタ |
| `\boldsymbol{\alpha}` | **α** | 太字シンボル |
| `\mathbb{A}` | 𝔸 | 黒板太字（amssymb必須） |
| `\mathfrak{A}` | 𝔄 | フラクトゥール（amssymb必須） |
| `\mathscr{A}` | 𝒜 | スクリプト（eucal[mathscr]必須） |

**注意**: STIX フォントパッケージでさらに多数のフォントが利用可能。

---

## 数学スペーシングコマンド

| 名称 | 幅 | 短縮形 | 長形式 |
|-----|-----|-------|--------|
| 1 mu (数式単位) | | | `\mspace{1mu}` |
| thin space | 3 mu | `\,` | `\thinspace` |
| medium space | 4 mu | `\:` | `\medspace` |
| thick space | 5 mu | `\;` | `\thickspace` |
| interword space | | `␣` (空白) | |
| 1 em | | `\quad` | |
| 2 em | | `\qquad` | |

### 負のスペース

| 名称 | 幅 | 短縮形 | 長形式 |
|-----|-----|-------|--------|
| -1 mu | | | `\mspace{-1mu}` |
| negative thin space | -3 mu | `\!` | `\negthinspace` |
| negative medium space | -4 mu | | `\negmedspace` |
| negative thick space | -5 mu | | `\negthickspace` |

**注意**: mu (math unit) は数式のフォントサイズに応じて自動調整される単位。
