# T-Ruby WebAssembly (WASM) Guide

T-Ruby supports compilation to WebAssembly, enabling you to run typed Ruby code in browsers, Node.js, and other WASM runtimes.

## Quick Start

### 1. Compile to WASM

```bash
# Compile a .trb file to WebAssembly
trc --wasm math.trb

# Output:
# Compiled: math.trb -> build/math.wat
# Binary:   build/math.wasm (if wat2wasm is available)
```

### 2. Use in Browser

```html
<!DOCTYPE html>
<html>
<head>
  <title>T-Ruby WASM Demo</title>
</head>
<body>
  <script>
    // Load and run the WASM module
    async function loadTRuby() {
      const importObject = {
        console: {
          log: (value) => console.log('T-Ruby:', value),
          log_str: (ptr, len) => {
            // String logging (requires memory access)
            const memory = instance.exports.memory;
            const bytes = new Uint8Array(memory.buffer, ptr, len);
            console.log('T-Ruby:', new TextDecoder().decode(bytes));
          }
        }
      };

      const response = await fetch('build/math.wasm');
      const bytes = await response.arrayBuffer();
      const { instance } = await WebAssembly.instantiate(bytes, importObject);

      // Call exported functions
      console.log('add(2, 3) =', instance.exports.add(2n, 3n));
      console.log('factorial(5) =', instance.exports.factorial(5n));
      console.log('fibonacci(10) =', instance.exports.fibonacci(10n));
    }

    loadTRuby();
  </script>
</body>
</html>
```

## Configuration

### Enable WASM in `.trb.yml`

```yaml
emit:
  rb: true
  wasm: true  # Enable WASM output

paths:
  src: ./src
  out: ./build
```

### Compile with Config

```bash
# Compiles all .trb files, generating both .rb and .wasm
trc src/
```

## Type Mapping

T-Ruby types are mapped to WASM types as follows:

| T-Ruby Type | WASM Type | Notes |
|-------------|-----------|-------|
| `Integer` | `i64` | 64-bit signed integer |
| `Float` | `f64` | 64-bit floating point |
| `Boolean` | `i32` | 0 = false, 1 = true |
| `String` | `i32` | Pointer to memory |
| `Array<T>` | `i32` | Pointer to memory |
| `nil` | `i32` | Value 0 |

## Supported Features

### Functions

All function definitions are exported and callable from JavaScript:

```ruby
# math.trb
def add(a: Integer, b: Integer): Integer
  a + b
end

def multiply(a: Integer, b: Integer): Integer
  a * b
end
```

```javascript
// JavaScript
const result = instance.exports.add(10n, 20n);  // 30n
```

> **Note:** WASM i64 values are represented as BigInt in JavaScript. Use `n` suffix or `BigInt()`.

### Arithmetic Operations

```ruby
def calculate(x: Integer, y: Integer): Integer
  a = x + y      # Addition
  b = x - y      # Subtraction
  c = x * y      # Multiplication
  d = x / y      # Division
  e = x % y      # Modulo
  a + b + c + d + e
end
```

### Comparison & Logic

```ruby
def compare(a: Integer, b: Integer): Boolean
  a > b && a != 0
end

def check(x: Integer): Boolean
  x >= 0 && x <= 100
end
```

### Control Flow

```ruby
# If/else
def max(a: Integer, b: Integer): Integer
  if a > b
    return a
  end
  b
end

# While loops
def sum_to_n(n: Integer): Integer
  result = 0
  i = 1
  while i <= n
    result = result + i
    i = i + 1
  end
  result
end
```

### Function Calls

```ruby
def double(x: Integer): Integer
  x * 2
end

def quadruple(x: Integer): Integer
  double(double(x))  # Calls double twice
end
```

## JavaScript Integration

### Basic Usage

```javascript
async function initTRuby() {
  const importObject = {
    console: {
      log: (value) => console.log(value),
      log_str: (ptr, len) => console.log('string at', ptr)
    }
  };

  const { instance } = await WebAssembly.instantiateStreaming(
    fetch('build/app.wasm'),
    importObject
  );

  return instance.exports;
}

// Usage
const truby = await initTRuby();
const result = truby.fibonacci(20n);
console.log('Fibonacci(20) =', result);
```

### With TypeScript

```typescript
interface TRubyExports {
  memory: WebAssembly.Memory;
  add(a: bigint, b: bigint): bigint;
  subtract(a: bigint, b: bigint): bigint;
  multiply(a: bigint, b: bigint): bigint;
  factorial(n: bigint): bigint;
  fibonacci(n: bigint): bigint;
}

async function loadTRuby(): Promise<TRubyExports> {
  const importObject = {
    console: {
      log: (value: bigint) => console.log(value),
      log_str: (ptr: number, len: number) => {}
    }
  };

  const response = await fetch('build/math.wasm');
  const bytes = await response.arrayBuffer();
  const { instance } = await WebAssembly.instantiate(bytes, importObject);

  return instance.exports as TRubyExports;
}
```

### Node.js Usage

```javascript
const fs = require('fs');

async function main() {
  const wasmBuffer = fs.readFileSync('build/math.wasm');

  const importObject = {
    console: {
      log: console.log,
      log_str: (ptr, len) => {}
    }
  };

  const { instance } = await WebAssembly.instantiate(wasmBuffer, importObject);

  console.log('Result:', instance.exports.add(100n, 200n));
}

main();
```

## Runtime Functions

T-Ruby WASM includes built-in runtime functions:

| Function | Signature | Description |
|----------|-----------|-------------|
| `abs` | `(i64) -> i64` | Absolute value |
| `min` | `(i64, i64) -> i64` | Minimum of two values |
| `max` | `(i64, i64) -> i64` | Maximum of two values |
| `puts_i64` | `(i64) -> void` | Print integer (calls console.log) |

```javascript
// These are available after loading the module
truby.abs(-42n);      // 42n
truby.min(10n, 20n);  // 10n
truby.max(10n, 20n);  // 20n
```

## Memory Management

T-Ruby WASM exports a `memory` object for string and array access:

```javascript
const { memory, exports } = instance;

// Read string from memory
function readString(ptr, len) {
  const bytes = new Uint8Array(memory.buffer, ptr, len);
  return new TextDecoder().decode(bytes);
}

// Write string to memory
function writeString(str, ptr) {
  const bytes = new TextEncoder().encode(str);
  const view = new Uint8Array(memory.buffer, ptr, bytes.length);
  view.set(bytes);
  return bytes.length;
}
```

## Canvas Graphics Example

Using T-Ruby WASM with HTML Canvas:

```ruby
# graphics.trb
def rgb(r: Integer, g: Integer, b: Integer): Integer
  (255 << 24) | (b << 16) | (g << 8) | r
end

def pixel_index(x: Integer, y: Integer, width: Integer): Integer
  (y * width + x) * 4
end

def distance_squared(x1: Integer, y1: Integer, x2: Integer, y2: Integer): Integer
  dx = x2 - x1
  dy = y2 - y1
  dx * dx + dy * dy
end
```

```html
<canvas id="canvas" width="400" height="400"></canvas>
<script>
  async function drawCircle() {
    const canvas = document.getElementById('canvas');
    const ctx = canvas.getContext('2d');
    const imageData = ctx.createImageData(400, 400);

    const { instance } = await WebAssembly.instantiateStreaming(
      fetch('build/graphics.wasm'),
      { console: { log: console.log, log_str: () => {} } }
    );

    const { distance_squared, rgb } = instance.exports;
    const centerX = 200n, centerY = 200n, radius = 100n;

    for (let y = 0; y < 400; y++) {
      for (let x = 0; x < 400; x++) {
        const dist = distance_squared(BigInt(x), BigInt(y), centerX, centerY);
        const idx = (y * 400 + x) * 4;

        if (dist <= radius * radius) {
          imageData.data[idx] = 255;     // R
          imageData.data[idx + 1] = 100; // G
          imageData.data[idx + 2] = 100; // B
          imageData.data[idx + 3] = 255; // A
        }
      }
    }

    ctx.putImageData(imageData, 0, 0);
  }

  drawCircle();
</script>
```

## Build Tools Integration

### Webpack

```javascript
// webpack.config.js
module.exports = {
  experiments: {
    asyncWebAssembly: true
  }
};
```

```javascript
// app.js
import wasmModule from './build/math.wasm';

async function init() {
  const instance = await wasmModule({
    console: { log: console.log, log_str: () => {} }
  });
  return instance.exports;
}
```

### Vite

```javascript
// vite.config.js
export default {
  build: {
    target: 'esnext'
  }
};
```

```javascript
// app.js
import init from './build/math.wasm?init';

const instance = await init({
  console: { log: console.log, log_str: () => {} }
});
```

## Installing wat2wasm

For binary WASM output, install the WebAssembly Binary Toolkit (wabt):

### macOS
```bash
brew install wabt
```

### Ubuntu/Debian
```bash
apt-get install wabt
```

### Windows
```bash
choco install wabt
```

### From Source
```bash
git clone https://github.com/WebAssembly/wabt
cd wabt
mkdir build && cd build
cmake ..
cmake --build .
```

## Limitations

Current WASM support has some limitations:

1. **No Garbage Collection**: Objects must be manually managed
2. **Limited String Support**: Strings are stored as pointers; complex operations require JS glue
3. **No Class Support**: Only functions are compiled
4. **No Metaprogramming**: Dynamic features are not available
5. **No Standard Library**: Ruby stdlib is not available
6. **No Exceptions**: Error handling uses return values

## Best Practices

1. **Use Type Annotations**: Always specify types for better WASM codegen
2. **Avoid Dynamic Features**: Stick to static, typed code
3. **Use Integer Arithmetic**: WASM excels at numeric computation
4. **Batch Operations**: Minimize JS-WASM boundary crossings
5. **Pre-allocate Memory**: Set up memory buffers once

## Debugging

### View Generated WAT

```bash
# WAT file is always generated
cat build/math.wat
```

### Validate WASM

```bash
# Using wasm-validate from wabt
wasm-validate build/math.wasm
```

### Debug in Browser

Chrome and Firefox have built-in WASM debugging:
1. Open DevTools → Sources
2. Find the WASM module
3. Set breakpoints in WAT source

## Performance Tips

1. **Use i64 for integers**: More efficient than f64 for whole numbers
2. **Inline small functions**: Avoid call overhead for simple operations
3. **Loop unrolling**: Manually unroll tight loops for speed
4. **Minimize memory access**: Cache values in local variables

## Example Project Structure

```
my-project/
├── src/
│   ├── math.trb        # Math utilities
│   ├── graphics.trb    # Graphics helpers
│   └── game.trb        # Game logic
├── web/
│   ├── index.html
│   └── app.js
├── build/
│   ├── math.wat
│   ├── math.wasm
│   └── ...
└── .trb.yml
```

## See Also

- [WebAssembly Specification](https://webassembly.org/specs/)
- [MDN WebAssembly Guide](https://developer.mozilla.org/en-US/docs/WebAssembly)
- [wabt: WebAssembly Binary Toolkit](https://github.com/WebAssembly/wabt)
