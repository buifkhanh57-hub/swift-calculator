# swift-calculator

An infix expression calculator in Swift with a hand-written
**recursive-descent parser**:

- Operator precedence: `+ -` < `* /` < `^` (right-associative power)
- Parentheses, unary minus, decimal numbers
- Interactive REPL via `swift run SwiftCalculator --repl`

## Build & run
```bash
swift run
# output:
# 2 + 3 * 4 = 14.0
# (2 + 3) * 4 = 20.0
# 2 ^ 3 ^ 2 = 512.0
```
