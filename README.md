# Archery Web Framework

**Archery** is a modern web framework for Dart, focused on clarity, performance, and developer flow.  
It reimagines the foundations of backend development with a modular, Laravel-inspired architecture built entirely in Dart.

> **Goal:** make backend programming in Dart as expressive and productive as Laravel or AdonisJS, with a compiler-level edge.

---

## Core Philosophy

- **Predictable:** explicit, type-safe architecture — no hidden magic.  
- **Minimal:** clean syntax, zero unnecessary abstractions.  
- **Composable:** small, testable primitives forming a cohesive system.  
- **Fast:** built directly on top of `dart:io` for native performance.

---

## 🧱 Core Modules

| Module    | Purpose                                          |
| :-------- | :----------------------------------------------- |
| `core`    | IoC container, providers, config repository      |
| `http`    | Routing, middleware, responses, request handling |
| `support` | Small utilities used across modules              |
---

## 🚀 Getting Started

### 1. Install

```bash
git clone https://github.com/webarchery/archery.git
cd archery
```

### 2. Quick Start

```dart
import 'package:archery/archery.dart';

void main() {
  final app = App();
  app.boot();
}
```

---

## Philosophy in Practice

Archery’s architecture mirrors real-world application design:

| Concept           | Dart Equivalent    | Example                            |
| :---------------- | :----------------- | :--------------------------------- |
| Service Container | `ServiceContainer` | Dependency resolution              |
| Provider          | `Provider`         | Register and boot services         |
| Config Loader     | `ConfigRepository` | Read nested configs easily         |
| Router            | `Router`           | Define HTTP routes with middleware |

---

## Running Tests

```bash
dart test
```

---
## Roadmap

* [x] Service Container
* [x] Provider Lifecycle
* [x] Config Repository
* [x] Router & Middleware
* [x] HTTP Kernel
* [x] Template Engine
* [ ] CLI Tooling (`archery new app`)
* [ ] ORM

---

## License

MIT © 2025 [WebArchery](https://github.com/webarchery)
