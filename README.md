# PhotoSwipeCleaner

A minimalist iOS app to clean up your photo library using intuitive swipe gestures.

## Features

- 🎴 **Tinder-style Swiping** - Swipe right to keep, swipe left to delete
- 📸 **Privacy First** - Photos are processed locally, nothing leaves your device
- 🔒 **Safety First** - Deleted photos go to "Recently Deleted" album first
- 🚀 **Fast & Lightweight** - Built with SwiftUI for smooth performance

## Requirements

- iOS 17.0+
- Xcode 15.0+
- macOS Sonoma 14.0+

## Getting Started

### Prerequisites

```bash
# Install XcodeGen
brew install xcodegen
```

### Setup

```bash
# Clone the repository
git clone <your-repo-url>
cd PhotoSwipeCleaner

# Generate Xcode project
./setup.sh

# Open in Xcode
open PhotoSwipeCleaner.xcodeproj
```

### Running

1. Open `PhotoSwipeCleaner.xcodeproj` in Xcode
2. Select your target device or simulator
3. Press `Cmd+R` to build and run

## Project Structure

```
PhotoSwipeCleaner/
├── App/                    # App entry point
├── Views/                  # SwiftUI views
├── Models/                 # Data models
├── ViewModels/             # MVVM view models
├── Services/               # Photo library services
└── Resources/              # Assets, preview content
```

## Roadmap

- [ ] Core swipe-to-delete functionality
- [ ] Batch delete confirmation
- [ ] Photo filtering (screenshots, duplicates)
- [ ] Blur detection for low-quality photos
- [ ] Statistics & insights

## Contributing

1. Create a feature branch (`git checkout -b feature/amazing-feature`)
2. Commit your changes (`git commit -m 'Add amazing feature'`)
3. Push to the branch (`git push origin feature/amazing-feature`)
4. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) for details.