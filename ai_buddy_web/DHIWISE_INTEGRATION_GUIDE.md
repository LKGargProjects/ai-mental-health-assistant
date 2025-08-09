# DhiWise Integration Guide

## Post-Export Integration Steps

### Step 1: Extract Export
1. Download the ZIP file from DhiWise
2. Extract to `/ai_buddy_web/lib/dhiwise_export/`
3. Review the generated structure

### Step 2: Copy Key Components
We'll copy these specific files:
- Chat screen widget
- Message bubble components
- Custom input field
- Theme/styling files
- Asset files

### Step 3: Integration Process
1. **Update imports** to match current project structure
2. **Integrate with existing providers** (ChatProvider, etc.)
3. **Update asset paths** to current project structure
4. **Test responsive behavior** on web
5. **Fine-tune styling** if needed

### Step 4: Testing Checklist
- [ ] Chat screen loads correctly
- [ ] Message bubbles display properly
- [ ] Input field works with existing ChatProvider
- [ ] Responsive design works on different screen sizes
- [ ] Assets load correctly
- [ ] No console errors

### Step 5: Cleanup
- Remove old chat screen implementation
- Update navigation routes
- Clean up unused imports

## Current Project Structure
```
ai_buddy_web/lib/
├── screens/
│   ├── chat_screen.dart (current - will be replaced)
│   └── chat_screen_backup.dart (backup)
├── widgets/
├── providers/
├── services/
└── dhiwise_export/ (new - for DhiWise files)
```

## Integration Notes
- Keep existing ChatProvider functionality
- Maintain API integration with backend
- Preserve crisis detection features
- Ensure web responsiveness
