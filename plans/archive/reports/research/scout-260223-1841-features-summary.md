# TaskManager Features Analysis Report

## AI Features

### AI Modes and Providers
- **Multiple AI Providers**: Google Gemini and z.ai
- **Built-in AI Modes**:
  - Correct Me (grammar/spelling editor)
  - Enhance Prompt (text expansion)
  - Explain (analysis with attachments support)
- **Custom AI Modes**: Users can create custom AI modes with system prompts
- **AI Model Support**: 
  - Gemini: gemini-flash-lite-latest, gemini-flash-latest, gemini-3-flash-preview
  - z.ai: GLM-4.6, GLM-4.7
- **Attachment Support**: Images and PDFs for Gemini provider

### Inline Enhancement System
- **Inline Enhance Coordinator**: System-wide text capture and replacement
- **Text Capture Engine**: Captures text from foreground applications
- **Text Replacement Engine**: Replaces selected text with AI-enhanced content
- **Browser Compatibility**: Special handling for Chrome, Safari, and Electron apps
- **HUD Interface**: Floating heads-up display showing capture results and enhancement options
- **Auto-dismiss**: Configurable timeout for HUD dismissal

### Enhance Me Panel
- **Dedicated AI Enhancement Window**: Quick access to AI enhancement
- **Text Input Area**: Rich text editor for task descriptions
- **Mode Selection**: Choose from available AI modes
- **Attachment Support**: Drag and drop images/PDFs
- **Real-time Enhancement**: Apply AI enhancements with one click

## Task Management Features

### Core Task Properties
- **Title and Description**: Rich text support with formatting
- **Status Management**: Todo, In Progress, Completed (with status cycling)
- **Priority Levels**: None, Low, Medium, High, Critical
- **Tags**: Tag system for organization and filtering
- **Sort Order**: Custom ordering for tasks

### Date and Time Management
- **Due Dates**: Set specific due dates for tasks
- **Reminders**: Configurable reminder system with duration (default 30 minutes)
- **Today Flag**: Mark tasks as "Today" for focus
- **Recurring Tasks**: 
  - Daily, Weekly, Monthly, Yearly, Weekdays
  - Custom interval support
  - Automatic task regeneration

### Photo and Attachment Support
- **Photo Storage**: Dedicated service for managing task photos
- **File Picker**: Native macOS file picker for image selection
- **Photo Display**: Photos stored in Application Support directory
- **Attachment Management**: Clean up of stale attachment files

### Custom Fields
- **Dynamic Field Creation**: Add custom field definitions
- **Multiple Field Types**: 
  - Text
  - Number
  - Currency
  - Date
  - Toggle (boolean)
- **Field Values**: Store custom data alongside tasks
- **Field Management**: Enable/disable and reorder fields

### Additional Task Properties
- **Budget Tracking**: Decimal field for monetary values
- **Client Information**: Text field for client names
- **Effort Tracking**: Double field for time/effort estimates
- **Creation/Update Tracking**: Automatic timestamps

## Views and Display

### List View
- **Task List View**: Main task listing interface
- **Task Rows**: Individual task display with priority indicators
- **Tag Cloud**: Visual tag representation
- **Priority Indicators**: Color-coded priority badges
- **Status Cycling**: Click to cycle through task statuses

### Kanban Board
- **Column-based Organization**: Todo, In Progress, Completed columns
- **Drag and Drop**: Move tasks between columns
- **Card View**: Rich task cards with all details
- **Column Management**: Dynamic column sizing and ordering

### Calendar View
- **Calendar Grid**: Month view with navigation
- **Date Selection**: Click dates to filter tasks
- **Visual Indicators**: 
  - Green dots: Tasks created on date
  - Red dots: Tasks with deadlines on date
  - Today highlighting
- **Month Navigation**: Previous/next month buttons

## Premium Features and Entitlements

### Subscription System
- **StoreKit Integration**: Native macOS subscription handling
- **Pro Tier**: Monthly/yearly subscriptions
- **VIP Tier**: Lifetime purchase option
- **Unified Entitlement**: Pro OR VIP OR admin grant = full access

### Premium Features
- **Kanban View**: Board-based task organization
- **Recurring Tasks**: Automated task repetition
- **Custom Fields**: Dynamic task properties
- **AI Attachments**: Image and PDF support for AI

### Access Control
- **Feature Gating**: Premium feature access validation
- **Admin Grant**: Debug option for testing VIP features
- **Restoration**: In-app purchase restoration
- **Status Tracking**: Real-time subscription status updates

## Global Shortcuts and Quick Entry

### System-Wide Shortcuts
- **Quick Entry**: ⌘⇧N - Global task creation
- **Enhance Me**: ⌘⇧E - Open AI enhancement panel
- **Main Window**: ⌘⇧T - Show/hide main app window
- **Inline Enhance**: ⌘⇧E - System-wide text enhancement
- **Settings**: ⌘, - Open settings when app focused

### App-Focused Shortcuts
- **New Task**: ⌘N - Create new task when app focused
- **Escape Handling**: Smart ESC key behavior
  - Dismiss floating windows
  - Close sheets/modals
  - Cancel text editing
  - Close main window

### Quick Entry Window
- **Floating Panel**: Non-intrusive task creation
- **Priority Selection**: Quick priority setting
- **Template Support**: Pre-filled task templates
- **Global Access**: Trigger from anywhere

## Settings and Configuration

### AI Configuration
- **Provider Settings**: Configure AI providers and models
- **Mode Management**: Add/edit/delete AI modes
- **Attachment Settings**: Enable/disable file attachments
- **Debug Mode**: Enhanced logging and troubleshooting

### General Settings
- **Appearance Mode**: System/Automorphic/Dark/Light
- **Window Behavior**: Always on top option
- **Inline Enhance**: Enable/disable system-wide enhancement
- **HUD Auto-dismiss**: Configurable timeout (5-60 seconds)

### Custom Fields Settings
- **Field Management**: Create, edit, delete custom fields
- **Type Selection**: Choose field type (text, number, etc.)
- **Activation**: Enable/disable fields
- **Sorting**: Reorder field display

### Shortcuts Settings
- **Shortcut Customization**: Modify global and app shortcuts
- **Reset Defaults**: Restore default key combinations
- **Visual Mapping**: Display current shortcut assignments

## Data Persistence

### SwiftData Integration
- **ModelContainer**: Core data container configuration
- **SwiftData Models**: 
  - TaskModel: Main task entity
  - AIModeModel: AI configuration
  - SettingsModel: App preferences
  - CustomFieldDefinitionModel: Field definitions
  - CustomFieldValueModel: Field values
- **Relationship Management**: Task-entity relationships
- **Unique Constraints**: Prevent duplicate data

### Data Management
- **Context Management**: Main context for operations
- **Fetch Descriptors**: Type-safe data queries
- **Model Configuration**: Container setup and configuration
- **Data Export**: Export functionality for backup

### Sync Considerations
- **No iCloud Sync**: Current implementation uses local storage only
- **File-based Storage**: Photos stored in local filesystem
- **Backup Options**: Data export service available
- **Migration Support**: Model versioning for schema changes

## Summary

The TaskManager application is a comprehensive task management solution with:

- **Advanced AI Integration**: Multiple providers, custom modes, and system-wide text enhancement
- **Rich Task Features**: Full CRUD operations with metadata, photos, custom fields
- **Multiple Views**: List, Kanban, and Calendar views for different workflows
- **Premium Model**: Subscription-based access to advanced features
- **Keyboard Excellence**: Extensive global and app shortcuts
- **Modern Architecture**: SwiftData-based with clean separation of concerns

**Key Strengths**: AI capabilities, view variety, keyboard shortcuts, customization options
**Areas for Growth**: iCloud sync, collaboration features, mobile apps
