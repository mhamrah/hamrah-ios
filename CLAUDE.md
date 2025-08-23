# Hamrah iOS App

## Overview
Hamrah is a productivity app that uses AI and ML to help users stay organized. It serves as your AI 'buddy' to remember everything so you don't have to, with deep integration into iOS.

## Core Principles

### Offline-First Architecture
- App functions without internet connectivity
- Local data storage with backend synchronization
- Graceful handling of network unavailability

### Performance & Speed
- Speed is a primary feature
- Extremely performant with clear background work indicators
- Fast, responsive interactions

### Modern UX/UI
- Clean, modern design following iOS best practices
- Motion, animation, and gradients for a "living" feel
- Deep iOS ecosystem integration to surface relevant information

## Technical Architecture

### Backend Integration
- **API**: `api.hamrah.app`
- **Protocol**: Protobuf serialization over HTTP
- **Related Projects**: 
  - API backend: `../hamrah-api`
  - Web app: `../hamrah-web` (Qwik framework)

### Data Strategy
- Local-first with backend synchronization
- Protobuf for efficient data serialization
- Recommended local storage options for iOS:
  - **Core Data**: Apple's native ORM with CloudKit sync capabilities
  - **SQLite**: Direct SQL with custom protobuf serialization layer
  - **Realm**: Modern database with sync capabilities
  - **SwiftData**: Apple's newest data framework (iOS 17+)

### Development Guidelines
- Always create tests to verify functionality
- Start with a test plan then implement until tests pass
- Prioritize performance in all implementations
- Follow iOS Human Interface Guidelines
- Implement proper offline/online state handling
