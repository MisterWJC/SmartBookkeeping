# SmartBookkeeping App
Smart Bookkeeping App - Your personal finance companion that gets smarter with every use.

## Key Features

### 🎯 AI-Powered Intelligence
*   **AI Confidence System:** Advanced AI system that learns from user behavior and provides intelligent transaction categorization with confidence scoring
*   **Smart Text Recognition:** Powered by Zhipu AI (GLM-4) for accurate extraction of transaction details from various text inputs
*   **Voice-to-Transaction:** Real-time speech recognition that converts spoken transaction details into structured data

### 📱 Core Functionality
*   **OCR Receipt Scanning:** Automatically extract transaction details from receipt images using Vision Framework
*   **Voice Recording & Recognition:** Record transaction details by voice and automatically process them with AI
*   **Manual Transaction Entry:** Add and edit transactions manually with comprehensive form validation
*   **Smart Quick Input:** AI-powered quick input that processes natural language transaction descriptions
*   **Transaction History:** View and manage comprehensive transaction records with advanced filtering
*   **Category Management:** Intelligent categorization with predefined expense and income categories
*   **Payment Method Tracking:** Support for multiple payment methods including digital wallets and bank cards

### 📊 Data & Analytics
*   **Real-time Processing:** Instant AI processing of transaction data with confidence scoring
*   **Data Persistence:** Secure local storage using Core Data with full CRUD operations
*   **Export Functionality:** Export transaction data in CSV/Excel formats for external analysis
*   **Monthly Summaries:** Automated calculation of income and expense totals

### 🔧 User Experience
*   **Guided Onboarding:** Interactive tutorial showcasing AI capabilities
*   **Configurable AI Settings:** User-configurable API keys and AI model parameters
*   **Multi-modal Input:** Support for voice, text, and image-based transaction entry
*   **Real-time Validation:** Instant feedback and error handling for all user inputs

## Getting Started

### Prerequisites
*   Xcode 15.0 or later
*   iOS 16.0 or later
*   Zhipu AI API key (for AI features)

### Installation
1.  Clone the repository:
    ```bash
    git clone https://github.com/your-username/SmartBookkeeping.git
    cd SmartBookkeeping
    ```
2.  Open `SmartBookkeeping.xcodeproj` in Xcode
3.  Configure your Zhipu AI API key in the app settings
4.  Build and run the app on a simulator or physical device

### Configuration

#### API Key Setup
To protect sensitive information, this project uses configuration files to manage API keys and other configuration data.

**Setup Steps:**
1. **Copy the example configuration file**
   ```bash
   cp SmartBookkeeping/Config.example.plist SmartBookkeeping/Config.plist
   ```

2. **Edit the configuration file**
   Open `SmartBookkeeping/Config.plist` and replace `YOUR_API_KEY_HERE` with your actual API key:
   ```xml
   <key>DefaultAPIKey</key>
   <string>your_actual_api_key</string>
   ```

3. **Get API Key**
   - Visit [Zhipu AI Open Platform](https://open.bigmodel.cn/)
   - Register an account and obtain an API key
   - Fill the key into the configuration file

**Configuration Files:**
- `Config.plist` - Actual configuration file (contains sensitive info, ignored by .gitignore)
- `Config.example.plist` - Example configuration file (safe to commit to version control)

**Important Notes:**
⚠️ **Important**: The `Config.plist` file contains sensitive information and should not be committed to version control.
✅ This file has been added to `.gitignore` to prevent accidental commits.

**Default Configuration:**
If `Config.plist` is not found, the app will use these defaults:
- Base URL: `https://open.bigmodel.cn/api/paas/v4`
- Model Name: `glm-4-air-250414`
- Free Uses: `50`
- API Key: None (requires manual configuration)

#### Other Settings
*   **AI API Setup:** Configure your Zhipu AI API key in Settings > API Configuration (alternative method)
*   **Permissions:** Grant microphone and photo library access for full functionality
*   **Categories:** Customize transaction categories to match your spending patterns

## Technologies Used

### Core Frameworks
*   **SwiftUI** - Modern declarative UI framework
*   **Core Data** - Local data persistence and management
*   **Vision Framework** - OCR text recognition from images
*   **Speech Framework** - Real-time speech recognition
*   **AVFoundation** - Audio recording and processing

### AI & Machine Learning
*   **Zhipu AI (GLM-4)** - Large language model for transaction data extraction
*   **Custom AI Confidence System** - Proprietary confidence scoring algorithm
*   **Natural Language Processing** - Advanced text parsing and categorization

### Architecture & Patterns
*   **MVVM Architecture** - Clean separation of concerns
*   **Combine Framework** - Reactive programming for data flow
*   **Swift Package Manager** - Dependency management
*   **Coordinator Pattern** - Navigation and flow management

## Product MVP

- **UI Designs and Demo Video:** You can find the UI documentation and a demo video for the product MVP in the `SmartBookkeeping-PRD/Presentations/` directory.
    - [SmartBookkeeping_MVP.pdf](./SmartBookkeeping-PRD/Presentations/SmartBookkeeping_MVP.pdf)
    - <video src="https://github.com/user-attachments/assets/7e212281-2918-4653-983e-b1096b40c1fe" controls width="600">
      </video>
      

## 💖 Support the Project
If this project has been helpful to you, consider buying me a coffee ☕
### WeChat Tip
<img src="./SmartBookkeeping-PRD/images/ali_reward.JPG" width="200" alt="WeChat Tip Code">

### Alipay Donation
<img src="./SmartBookkeeping-PRD/images/wechat_reward.JPG" width="200" alt="Alipay Payment Code">

### Other Ways to Support

- ⭐ Star the project on GitHub
- 🐛 Submit issues or pull requests
- 📢 Share with friends and colleagues
