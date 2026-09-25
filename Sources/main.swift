// swift-calculator — an infix expression calculator with a
// recursive-descent parser. Run: swift run

import Foundation

enum Token: Equatable {
    case number(Double)
    case op(Character)
    case lparen
    case rparen
}

enum CalcError: Error, CustomStringConvertible {
    case invalidCharacter(Character)
    case unexpectedEnd
    case syntax(String)

    var description: String {
        switch self {
        case .invalidCharacter(let c): return "ky tu khong hop le: '\(c)'"
        case .unexpectedEnd: return "bieu thuc ket thuc dot ngot"
        case .syntax(let msg): return "loi cu phap: \(msg)"
        }
    }
}

func tokenize(_ input: String) throws -> [Token] {
    var tokens: [Token] = []
    var index = input.startIndex

    while index < input.endIndex {
        let c = input[index]
        if c.isWhitespace {
            index = input.index(after: index)
            continue
        }
        if c.isNumber || c == "." {
            var num = String(c)
            index = input.index(after: index)
            while index < input.endIndex, input[index].isNumber || input[index] == "." {
                num.append(input[index])
                index = input.index(after: index)
            }
            guard let value = Double(num) else {
                throw CalcError.syntax("so khong hop le: \(num)")
            }
            tokens.append(.number(value))
            continue
        }
        switch c {
        case "+", "-", "*", "/", "^":
            tokens.append(.op(c))
        case "(": tokens.append(.lparen)
        case ")": tokens.append(.rparen)
        default: throw CalcError.invalidCharacter(c)
        }
        index = input.index(after: index)
    }
    return tokens
}

// Grammar:
//   expr   := term (('+' | '-') term)*
//   term   := factor (('*' | '/') factor)*
//   factor := base ('^' factor)?          // right associative power
//   base   := number | '(' expr ')' | ('-' base)
struct Parser {
    let tokens: [Token]
    var pos = 0

    mutating func peek() -> Token? {
        pos < tokens.count ? tokens[pos] : nil
    }

    mutating func advance() -> Token? {
        defer { pos += 1 }
        return peek()
    }

    mutating func parseExpr() throws -> Double {
        var left = try parseTerm()
        while case .op(let op)? = peek(), op == "+" || op == "-" {
            _ = advance()
            let right = try parseTerm()
            left = op == "+" ? left + right : left - right
        }
        return left
    }

    mutating func parseTerm() throws -> Double {
        var left = try parseFactor()
        while case .op(let op)? = peek(), op == "*" || op == "/" {
            _ = advance()
            let right = try parseFactor()
            if op == "/" && right == 0 { throw CalcError.syntax("chia cho 0") }
            left = op == "*" ? left * right : left / right
        }
        return left
    }

    mutating func parseFactor() throws -> Double {
        let base = try parseBase()
        if case .op(let op)? = peek(), op == "^" {
            _ = advance()
            let exponent = try parseFactor() // right associative
            return pow(base, exponent)
        }
        return base
    }

    mutating func parseBase() throws -> Double {
        guard let token = advance() else { throw CalcError.unexpectedEnd }
        switch token {
        case .number(let v):
            return v
        case .lparen:
            let value = try parseExpr()
            guard case .rparen? = advance() else {
                throw CalcError.syntax("thieu dau )")
            }
            return value
        case .op(let op) where op == "-":
            return -try parseBase()
        default:
            throw CalcError.syntax("khong mong doi token nay")
        }
    }
}

func evaluate(_ expression: String) throws -> Double {
    var parser = Parser(tokens: try tokenize(expression))
    let value = try parser.parseExpr()
    if parser.pos != parser.tokens.count {
        throw CalcError.syntax("du token thua o cuoi bieu thuc")
    }
    return value
}

// ------------------------------------------------------------- REPL ------

func repl() {
    print("Swift Calculator — nhap bieu thuc (hoac 'exit' de thoat)")
    while true {
        print("calc> ", terminator: "")
        guard let line = readLine() else { break }
        let text = line.trimmingCharacters(in: .whitespaces)
        if text.isEmpty { continue }
        if ["exit", "quit"].contains(text.lowercased()) { break }
        do {
            let value = try evaluate(text)
            print("= \(value)")
        } catch {
            print("Loi: \(error)")
        }
    }
}

let tests = [
    "2 + 3 * 4",        // 14
    "(2 + 3) * 4",      // 20
    "2 ^ 3 ^ 2",        // 512
    "-5 + 10",          // 5
    "100 / 8"           // 12.5
]

for expr in tests {
    let value = try! evaluate(expr)
    print("\(expr) = \(value)")
}

if CommandLine.arguments.contains("--repl") {
    repl()
}
