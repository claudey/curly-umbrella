# BrokerSync Dashboard Information Architecture

## Overview
This document outlines the information architecture for the BrokerSync dashboard pages, providing a structured approach to organizing content, styling sections, and maintaining consistency across the application.

## Layout Structure

### Main Application Layout (`application.html.erb`)
```
┌─────────────────────────────────────────────────────────────┐
│                    DaisyUI Drawer Layout                   │
├─────────────────────────────────────────────────────────────┤
│ ┌─────────────────┐ ┌─────────────────────────────────────┐ │
│ │   Sidebar       │ │          Main Content Area          │ │
│ │   (drawer-side) │ │         (drawer-content)            │ │
│ │                 │ │ ┌─────────────────────────────────┐ │ │
│ │ Navigation Menu │ │ │           Navbar                │ │ │
│ │ - Dashboard     │ │ ├─────────────────────────────────┤ │ │
│ │ - Clients       │ │ │        Flash Messages           │ │ │
│ │ - Applications  │ │ ├─────────────────────────────────┤ │ │
│ │ - Quotes        │ │ │                                 │ │ │
│ │ - Documents     │ │ │        Page Content             │ │ │
│ │ - Companies     │ │ │         (yield)                 │ │ │
│ │ - Reports       │ │ │                                 │ │ │
│ │ - Settings      │ │ │                                 │ │ │
│ │ - Admin         │ │ │                                 │ │ │
│ └─────────────────┘ │ └─────────────────────────────────┘ │ │
└─────────────────────────────────────────────────────────────┘
```

## Dashboard Page Structure (`home/index.html.erb`)

### 1. Page Header Section
**Purpose**: Welcome user and provide primary actions
**Location**: Top of main content area
**DaisyUI Classes**: `flex justify-between items-center mb-6`

```
┌─────────────────────────────────────────────────────────────┐
│ Dashboard                    [Upload Document] [View All]   │
│ Welcome back, User! Here's what's happening...              │
└─────────────────────────────────────────────────────────────┘
```

**Components**:
- Page title (h1)
- Welcome message with user name
- Primary action buttons (Upload, View All)

### 2. Key Metrics Row
**Purpose**: Display critical business metrics at a glance
**Location**: Below page header
**DaisyUI Classes**: `grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6`

```
┌───────────────┐ ┌───────────────┐ ┌───────────────┐ ┌───────────────┐
│ Total Docs    │ │ Active Docs   │ │ Expiring Soon │ │ Storage Used  │
│      0        │ │      0        │ │      0        │ │     0 B       │
│ +0 this month │ │ 0.0% of total │ │ Next 7 days   │ │ Across all    │
└───────────────┘ └───────────────┘ └───────────────┘ └───────────────┘
```

**Metric Cards**:
1. **Total Documents** (Primary theme - blue)
2. **Active Documents** (Success theme - green)
3. **Expiring Soon** (Warning theme - yellow)
4. **Storage Used** (Info theme - cyan)

### 3. Main Content Grid
**Purpose**: Primary dashboard content in two-column layout
**Location**: Below metrics
**DaisyUI Classes**: `grid grid-cols-1 lg:grid-cols-3 gap-6`

#### Left Column (2/3 width) - `lg:col-span-2`

##### 3.1 Recent Documents Table
**Purpose**: Show latest document activity
**DaisyUI Classes**: `card bg-base-100 shadow-xl`

```
┌─────────────────────────────────────────────────────────────┐
│ Recent Documents                              [View All]    │
├─────────────────────────────────────────────────────────────┤
│ Document | Type | Size | Created | Actions                  │
├─────────────────────────────────────────────────────────────┤
│ 📄 Doc1  │[Tag] │ 2MB  │ 2h ago  │ [View] [Download]        │
│ 📄 Doc2  │[Tag] │ 1MB  │ 3h ago  │ [View] [Download]        │
└─────────────────────────────────────────────────────────────┘
```

##### 3.2 Document Types Overview
**Purpose**: Visual breakdown of document categories
**DaisyUI Classes**: `card bg-base-100 shadow-xl`

```
┌─────────────────────────────────────────────────────────────┐
│ Document Types Overview                                     │
├─────────────────────────────────────────────────────────────┤
│ 📁 Insurance Policies    [5] ████████████░░░░                │
│ 📁 Claims               [3] ████████░░░░░░░░                 │
│ 📁 Quotes               [2] █████░░░░░░░░░░░                 │
└─────────────────────────────────────────────────────────────┘
```

#### Right Column (1/3 width) - Sidebar Content

##### 3.3 Quick Actions
**Purpose**: Primary user actions
**DaisyUI Classes**: `card bg-base-100 shadow-xl`

```
┌─────────────────────────────────────┐
│ Quick Actions                       │
├─────────────────────────────────────┤
│ [📤 Upload Document        ]        │
│ [🔍 Browse Documents       ]        │
│ [📦 View Archived          ]        │
│ [⏰ Expiring Documents     ]        │
└─────────────────────────────────────┘
```

##### 3.4 Upcoming Tasks
**Purpose**: Show pending work items
**DaisyUI Classes**: `card bg-base-100 shadow-xl`

```
┌─────────────────────────────────────┐
│ Upcoming Tasks                      │
├─────────────────────────────────────┤
│ Task 1                    [HIGH]    │
│ Description...                      │
│                                     │
│ Task 2                    [MED]     │
│ Description...                      │
└─────────────────────────────────────┘
```

##### 3.5 My Recent Documents
**Purpose**: User's personal document activity
**DaisyUI Classes**: `card bg-base-100 shadow-xl`

```
┌─────────────────────────────────────┐
│ My Recent Documents                 │
├─────────────────────────────────────┤
│ 📄 Document 1                       │
│    2h ago • 1.5MB                   │
│                                     │
│ 📄 Document 2                       │
│    4h ago • 2.1MB                   │
│                                     │
│ [View all my documents]             │
└─────────────────────────────────────┘
```

##### 3.6 Storage & System Info
**Purpose**: System statistics and usage metrics
**DaisyUI Classes**: `card bg-base-100 shadow-xl`

```
┌─────────────────────────────────────┐
│ Storage & System Info               │
├─────────────────────────────────────┤
│ Documents               0           │
│ Total Storage          0 B          │
│ Organization Users     7            │
│ ─────────────────────────────────── │
│ Top Categories                      │
│ Insurance              [3]          │
│ Claims                 [2]          │
└─────────────────────────────────────┘
```

## Navigation Structure

### Primary Navigation (Sidebar)
**Organization**: Functional grouping with collapsible sections

1. **Dashboard** (Single item)
2. **Clients** (Expandable)
   - All Clients
   - Add Client
3. **Applications** (Expandable)
   - Motor Insurance
   - Life Insurance
   - Fire Insurance
   - Residential Insurance
4. **Quotes** (Expandable)
   - All Quotes
   - Pending Reviews
   - Expiring Soon
5. **Documents** (Expandable)
   - All Documents
   - Upload Document
   - Archived
   - Expiring Soon
6. **Insurance Companies** (Expandable)
   - All Companies
   - Pending Approval
7. **Reports** (Expandable)
   - Performance
   - Analytics
8. **Settings** (Expandable)
   - Organization
   - Users
   - Preferences
9. **Administration** (Super Admin Only)
   - Organizations
   - Analytics
   - System Settings
   - Audit Logs

## DaisyUI Theme Components Used

### Color Themes
- **Primary**: Blue tones for main actions and total metrics
- **Success**: Green for positive metrics (active documents)
- **Warning**: Yellow/Orange for attention items (expiring documents)
- **Info**: Cyan for informational metrics (storage)
- **Error**: Red for critical alerts
- **Base-100**: White/light background for cards
- **Base-200**: Light gray for subtle backgrounds
- **Base-300**: Medium gray for navbar

### Component Categories

#### Layout Components
- `drawer` - Main layout container
- `drawer-content` - Main content area
- `drawer-side` - Sidebar navigation
- `navbar` - Top navigation bar
- `grid` - CSS Grid layout system

#### Content Components
- `card` - Content containers
- `table` - Data tables
- `menu` - Navigation menus
- `badge` - Status indicators
- `progress` - Progress bars
- `alert` - Flash messages

#### Interactive Components
- `btn` - Buttons with variants (primary, outline, ghost)
- `dropdown` - User menu dropdown
- `details/summary` - Collapsible navigation sections

## Responsive Behavior

### Breakpoints
- **Mobile (< 768px)**: Single column layout, hidden sidebar
- **Tablet (768px - 1024px)**: Two-column metrics, collapsible sidebar
- **Desktop (> 1024px)**: Full layout with persistent sidebar

### Mobile Adaptations
- Metrics cards stack vertically
- Tables become horizontally scrollable
- Sidebar becomes overlay drawer
- Hamburger menu for navigation toggle

## Styling Guidelines

### Spacing
- **Section gaps**: `gap-6` (24px)
- **Card padding**: `card-body` (standard DaisyUI padding)
- **Element margins**: `mb-4`, `mb-6` for consistent vertical rhythm

### Typography
- **Page titles**: `text-3xl font-bold`
- **Card titles**: `card-title`
- **Body text**: Default DaisyUI text sizing
- **Meta text**: `text-sm opacity-70`

### Visual Hierarchy
1. **Page Header** - Largest, most prominent
2. **Metric Cards** - Eye-catching with color coding
3. **Section Titles** - Clear delineation of content areas
4. **Content Items** - Scannable with consistent formatting

## Content Prioritization

### Above the fold (Primary focus)
1. Welcome message and primary actions
2. Key business metrics
3. Recent activity

### Below the fold (Secondary focus)
1. Detailed data tables
2. Charts and analytics
3. System information

### Sidebar (Tertiary focus)
1. Quick actions
2. Personal activity
3. System stats

## Future Considerations

### Extensibility
- Modular card system for easy addition of new metrics
- Configurable dashboard layouts
- User customization preferences
- Widget-based architecture

### Performance
- Lazy loading for secondary content
- Pagination for large data sets
- Caching strategies for metrics
- Progressive enhancement

This information architecture provides a solid foundation for maintaining consistent styling and logical content organization across the BrokerSync dashboard.