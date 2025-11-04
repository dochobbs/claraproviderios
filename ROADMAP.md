# Clara Provider iOS - Product Roadmap

**Last Updated**: November 4, 2025

## Completed ✅

### Critical Bug Fixes (Session 1)
- ✅ **Font Loading** - Implemented CTFontManager dynamic font registration to load RethinkSans fonts at app startup
- ✅ **Notification Bubbles** - Fixed non-reactive alert bindings (.constant → .init(get:set:)) across 4 views
- ✅ **Data Reload on Unlock** - Added bypassDebounce parameter to bypass 30-second debounce when app unlocks

### Security & Cleanup (Previous Sessions)
- ✅ Remove all PHI from console logs (patient names, ages, medical summaries)
- ✅ Fix UUID validation fallback bugs (prevent opening wrong patient's data)
- ✅ Input validation for messages and passwords (length limits, trim whitespace)
- ✅ PBKDF2 password hashing with random salt (not vulnerable SHA256)
- ✅ Fix NotificationCenter observer memory leak
- ✅ Fix auto-refresh task accumulation leak
- ✅ Face ID privacy description in project.pbxproj

---

## Current Sprint

### High Priority - Implement Now

1. **FEATURE: Add undo send functionality with delayed message delivery**
   - Details TBD
   - Delay duration: TBD
   - UX: Toast with undo button during delay window
   - Message goes back to editable state if undone

2. **FEATURE: Add quick message parent button - redirect to external SMS/messaging**
   - Button in conversation detail toolbar
   - Opens Google Voice, WhatsApp, or SMS with parent phone number pre-filled
   - Provider handles messaging outside app
   - Store parent phone number in conversation data
   - Simpler than in-app E2E messaging (outsource to proven services)

3. **FEATURE: Add follow-up request functionality**
   - Provider can push follow-up request to Clara from conversation
   - Clara follows up with parent on schedule
   - Details TBD (follow-up types, timing, storage)

4. **FEATURE: Add flag conversation functionality with reason modal**
   - Button in conversation detail toolbar
   - Modal with optional reason/note field
   - Flags conversation for provider attention
   - Updates Supabase status field

5. **FEATURE: Add 'Flagged' filter button to conversation list**
   - Add to status filter bar (Pending, All, Flagged)
   - Show count of flagged conversations
   - Filter conversations by flagged status

6. **FEATURE: Implement dot phrases for quick text entry (hardcoded)**
   - Dictionary of dot codes → expansions
   - Example: `.wNL` → "within normal limits"
   - Text replacement on space/punctuation
   - Applied to message input views
   - No autocomplete UI (v1)

---

## Security & Infrastructure

7. **SECURITY: Rotate Supabase API Key to Keychain**
   - Move from hardcoded string to Keychain storage
   - Encrypt at rest on device
   - Add fallback for first app launch

8. **SECURITY: Move Claude API key from UserDefaults to Keychain**
   - Currently stored insecurely in UserDefaults
   - Implement Keychain storage with error handling
   - Fallback initialization for first app launch

9. **SECURITY: Add input validation to all text inputs**
   - Already done for messages and passwords
   - Apply to all other text entry points
   - Trim whitespace, enforce length limits
   - Prevent DoS from extremely long inputs

---

## Features & Enhancements

10. **FEATURE: Implement proper password reset/change flow**
    - Allow providers to change password
    - Security questions or email verification?
    - Details TBD

11. **BUG: Fix pull-to-refresh indicator styling and behavior**
    - Ensure refresh indicator displays correctly
    - Test on all iOS versions

12. **FEATURE: Add search/filter functionality for conversations**
    - Filter by patient name, conversation title, date range
    - Save filter preferences?

13. **UX: Improve loading states and skeleton screens**
    - Add skeleton screens for conversation list
    - Better loading indicators during data fetch
    - Handle slow network gracefully

14. **REFACTOR: Extract repeated UI patterns into reusable components**
    - ConversationRow, MessageBubble, StatusBadge patterns
    - DRY up view code
    - Easier to maintain and test

---

## Testing & Documentation

15. **TESTING: Add unit tests for authentication flows**
    - Test password hashing
    - Test lock/unlock state transitions
    - Test session expiry

16. **TESTING: Add unit tests for data store operations**
    - Test loadReviewRequests with/without debounce
    - Test refresh timing and caching
    - Test error handling

17. **DOCUMENTATION: Document API endpoint integration flow**
    - Map all Supabase endpoints used
    - Document data models and relationships
    - API request/response examples

18. **DOCUMENTATION: Add inline code comments for critical sections**
    - Security-critical code
    - Performance optimizations
    - Complex business logic

19. **PERFORMANCE: Implement efficient pagination for large conversation lists**
    - Load conversations in batches (20-50 at a time)
    - Lazy loading as user scrolls
    - Reduce initial load time

20. **ACCESSIBILITY: Add VoiceOver support for all interactive elements**
    - Accessibility labels on buttons
    - Proper heading hierarchy
    - Test with VoiceOver enabled

21. **LOCALIZATION: Prepare app for multi-language support**
    - Extract all hardcoded strings to Localizable.strings
    - Support Spanish, Portuguese (parent app languages?)
    - Date/time formatting for different locales

---

## Architecture Notes

### Key Systems
- **Authentication**: PBKDF2 password hashing, Face ID biometrics, 12-hour session timeout
- **Data Sync**: Supabase backend with 30-second debounce on auto-refresh
- **State Management**: ProviderConversationStore (@ObservableObject)
- **Notifications**: Push notifications + local NotificationCenter observers
- **Storage**: Keychain for sensitive data, UserDefaults for preferences

### Performance Considerations
- Auto-refresh timer: 60 seconds
- Debounce interval: 30 seconds (prevents excessive view updates)
- Session timeout: 12 hours
- Message length limit: 5000 characters
- Password length: 8-512 characters

### Security Considerations
- All API keys must move to Keychain (not hardcoded or UserDefaults)
- Input validation on all text fields
- No PHI in console logs (use os_log with public filtering)
- UUID validation before navigation (prevent HIPAA violations)
- Proper password hashing with salt (not plain text or unsalted SHA256)

---

## Recent Commits

```
835a000 - FIX: Data reload on app unlock - bypass debounce for forced refresh
198867d - FIX: Replace non-reactive alert bindings with proper two-way bindings
25b13a9 - FIX: Use CTFontManager to dynamically load fonts
bbec27e - DEBUG: Add font loading diagnostics
96581ae - SECURITY/HIPAA FIX - Remove all PHI from console logs
696a10f - SECURITY/HIPAA FIX - Fix UUID validation fallback bugs
```

---

## Next Steps

1. **Immediately**: Start on dot phrases feature (quickest win, ~30-45 min)
2. **Soon**: Implement flag conversation + filter functionality
3. **Next Week**: Plan E2E messaging architecture with stakeholders
4. **Ongoing**: Move API keys to Keychain (security priority)

---

## Questions for Product/Design

- **Dot phrases**: What clinical phrases should be in v1? Editable by user later?
- **Follow-ups**: What are the follow-up types and timing options?
- **E2E Messaging**: Encryption method? Delivery infrastructure? Push notifications?
- **Undo Send**: How long should the undo window be? 5s? 10s? User-configurable?
- **Password Reset**: Via email? Security questions? Phone verification?

