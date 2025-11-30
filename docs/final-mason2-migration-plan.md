# Final Mason2 Template Elimination - Migration Plan

**Status**: Planning Phase
**Date**: 2025-11-29
**Goal**: Eliminate the last 2 Mason2 page templates (Full-Text Search, Sign Up)

---

## Overview

Three final Mason2 templates remain to be migrated:

1. **maintenance_display.mc** - ✅ **COMPLETE** (migrated to React SystemNode component)
2. **e2_full_text_search.mc** - Google Custom Search integration
3. **sign_up.mc** - User registration with email confirmation

This document outlines the migration strategy for the remaining two templates.

---

## 1. Full-Text Search Migration

### Current Implementation

**Template**: `templates/pages/e2_full_text_search.mc`
**Page Class**: `Everything::Page::e2_full_text_search` (empty stub)
**Technology**: Google Custom Search Engine (CSE) via JavaScript iframe

**How it works**:
- Mason template injects Google CSE JavaScript and form
- Search queries submitted to Google's servers
- Results rendered via Google's iframe in `<div id="cse-search-results">`
- Custom Search ID: `017923811620760923756:pspyfx78im4`

**Database Impact**: **NONE** - All search happens on Google's servers

### Migration Strategy

**Recommendation**: **Simple React Port** (Low Risk)

Since this feature uses Google CSE and doesn't touch the database, migration is straightforward:

#### Implementation Steps

1. **Create React Component**: `react/components/Documents/FullTextSearch.js`
   - Port the Google CSE form HTML to JSX
   - Load Google CSE JavaScript via `useEffect` hook
   - Initialize CSE after component mounts

2. **Create Page Class**: Update `e2_full_text_search.pm`
   ```perl
   sub buildReactData {
     my ($self, $REQUEST) = @_;
     return {
       type => 'full_text_search',
       cseId => '017923811620760923756:pspyfx78im4',
       formId => 'cse-search-box',
       resultsId => 'cse-search-results'
     };
   }
   ```

3. **Update DocumentComponent**: Add route to component map

4. **Delete Mason Template**: Remove `templates/pages/e2_full_text_search.mc`

#### React Component Structure

```javascript
const FullTextSearch = ({ data }) => {
  useEffect(() => {
    // Load Google CSE stylesheet
    const link = document.createElement('link')
    link.rel = 'stylesheet'
    link.href = 'https://www.google.com/cse/api/branding.css'
    document.head.appendChild(link)

    // Load Google CSE JavaScript
    const script = document.createElement('script')
    script.src = 'https://www.google.com/afsonline/show_afs_search.js'
    script.async = true
    document.body.appendChild(script)

    return () => {
      // Cleanup on unmount
      document.head.removeChild(link)
      document.body.removeChild(script)
    }
  }, [])

  return (
    <div className="full-text-search">
      <div className="cse-branding-right">
        <form id={data.formId} action="">
          <input type="hidden" name="cx" value={data.cseId} />
          <input type="hidden" name="cof" value="FORID:9" />
          <input type="hidden" name="ie" value="UTF-8" />
          <input type="text" name="q" size="31" />
          <input type="submit" name="sa" value="Search" />
        </form>
      </div>
      <div id={data.resultsId}></div>
    </div>
  )
}
```

#### Testing Plan

- **Manual Testing**: Verify search form loads and submits
- **Integration**: Confirm Google CSE iframe renders results
- **Cross-browser**: Test in Chrome, Firefox, Safari
- **Accessibility**: Ensure form labels and ARIA attributes

#### Risks

- **Low Risk**: No database queries, no server-side logic
- **Third-party Dependency**: Relies on Google CSE continuing to work
- **Alternative**: If Google CSE is deprecated, consider migrating to Elasticsearch or similar

---

## 2. Sign Up Page Migration

### Current Implementation

**Template**: `templates/pages/sign_up.mc` (115 lines)
**Page Class**: `Everything::Page::sign_up` (259 lines)
**Technology**:
- reCAPTCHA v3 for spam protection
- Amazon SES for email delivery
- Form field hashing for email/password confirmation
- IP blacklisting and spam domain checking

**Email Flow**:
1. User submits form → Server validates
2. Server creates locked user account
3. Server sends activation email via SES (template: "Welcome to Everything2" mail node)
4. User clicks link → Account activated

### Migration Challenges

#### 1. Form Field Hashing

**Current**: Uses `Everything::Form::field_hashing` role
- Hashes email/password fields client-side before submission
- Compares hashed values server-side to verify match
- Prevents password/email from being transmitted in plain text

**Solution**: Port hashing logic to React
```javascript
// Client-side hashing in React
import { SHA256 } from 'crypto-js'

const hashField = (fieldName, value, formTime) => {
  return SHA256(fieldName + value + formTime).toString()
}
```

#### 2. reCAPTCHA v3 Integration

**Current**: Google reCAPTCHA v3 loaded via script tag
- Public key from config: `$CONF->recaptcha_v3_public_key`
- Token submitted with form
- Server validates via Google API

**Solution**: React component with reCAPTCHA hook
```javascript
useEffect(() => {
  const script = document.createElement('script')
  script.src = `https://www.google.com/recaptcha/api.js?render=${publicKey}`
  document.body.appendChild(script)

  script.onload = () => {
    grecaptcha.ready(() => {
      grecaptcha.execute(publicKey, { action: 'signup' })
        .then(token => setRecaptchaToken(token))
    })
  }
}, [])
```

#### 3. Email Testing & Debugging

**Critical Need**: End-to-end testing for email delivery

**Current Setup**:
- Production uses Amazon SES
- Development/staging unclear if SES is configured

**Testing Strategy**:

##### Option A: Mock Email in Development
```perl
# In Everything::Page::sign_up::display
if (!$self->CONF->is_production) {
  # Log email instead of sending
  $self->APP->devLog("MOCK EMAIL: To=$email, Subject=Welcome, Body=$mail->{doctext}");
  # Still return success
}
```

##### Option B: SES Sandbox Mode
- Configure SES in sandbox mode for development
- Verify recipient email addresses
- Test actual email delivery without production impact

##### Option C: Email Testing Tool Integration
- Use services like Mailtrap or Mailhog
- Capture outgoing emails in development
- Inspect email content without actual delivery

**Recommendation**: **Option A (Mock) + Option B (SES Sandbox)**
- Mock emails in local development (`devLog` output)
- SES sandbox for staging environment testing
- Verify email templates render correctly

#### 4. Security Validations

**Must Preserve**:
- IP blacklist checking
- Known spam domain filtering
- Locked user email detection
- Cookie infection detection
- Username validation regex
- reCAPTCHA score thresholds

**Implementation**: Keep all validation in `sign_up.pm::display()`, just change response format

### Migration Strategy

**Recommendation**: **Hybrid Approach** (Moderate Risk)

Keep server-side logic intact, migrate only the presentation layer:

#### Implementation Steps

**Phase 1: React Component** (2-3 hours)
1. Create `react/components/Documents/SignUp.js`
2. Port form HTML to JSX
3. Implement client-side field hashing
4. Add reCAPTCHA v3 integration
5. Handle success/error states

**Phase 2: API Endpoint** (1-2 hours)
1. Create `Everything::API::signup` endpoint
2. Move validation logic from `sign_up.pm::display()` to API
3. Return JSON responses (success/error)

**Phase 3: Testing Infrastructure** (2-3 hours)
1. Add email mocking for development
2. Configure SES sandbox for staging
3. Create E2E test for full signup flow
4. Test email delivery end-to-end

**Phase 4: Migration** (1 hour)
1. Update `sign_up.pm` to use `buildReactData()`
2. Route to React component
3. Delete Mason template

#### React Component Structure

```javascript
const SignUp = ({ data, user }) => {
  const [formData, setFormData] = useState({
    username: '',
    password: '',
    confirmPassword: '',
    email: '',
    confirmEmail: ''
  })
  const [recaptchaToken, setRecaptchaToken] = useState('')
  const [error, setError] = useState('')
  const [success, setSuccess] = useState(false)

  // Load reCAPTCHA v3
  useEffect(() => {
    if (!data.useRecaptcha) return
    // ... load and execute reCAPTCHA
  }, [])

  const handleSubmit = async (e) => {
    e.preventDefault()

    // Hash email and password
    const hashedEmail = hashField('email', formData.confirmEmail, Date.now())
    const hashedPassword = hashField('pass', formData.confirmPassword, Date.now())

    // Submit to API
    const response = await fetch('/api/signup', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        username: formData.username,
        email: formData.email,
        pass: formData.password,
        email_hash: hashedEmail,
        pass_hash: hashedPassword,
        recaptcha_token: recaptchaToken
      })
    })

    const result = await response.json()
    if (result.success) {
      setSuccess(true)
    } else {
      setError(result.prompt)
    }
  }

  if (success) {
    return <SuccessMessage username={formData.username} />
  }

  return <SignUpForm onSubmit={handleSubmit} error={error} />
}
```

#### API Endpoint (`Everything::API::signup`)

```perl
sub signup {
  my ($self, $REQUEST) = @_;

  # Parse JSON body
  my $data = $self->JSON_POSTDATA($REQUEST);

  # Validate all fields (port from sign_up.pm::display)
  my $prompt = $self->validate_signup($REQUEST, $data);

  if ($prompt) {
    return [$self->HTTP_BAD_REQUEST, { error => $prompt }];
  }

  # Create user
  my $new_user = $self->APP->create_user($data->{username}, $data->{pass}, $data->{email});

  # Send activation email
  $self->send_activation_email($new_user, $data->{pass});

  return [$self->HTTP_OK, {
    success => 1,
    username => $data->{username},
    linkvalid => 10
  }];
}
```

#### Testing Plan

**Unit Tests**:
- Form validation logic
- Field hashing algorithm
- API endpoint responses

**Integration Tests**:
- reCAPTCHA integration
- Email sending (mocked)
- Account creation flow

**E2E Tests** (`tests/e2e/signup.spec.js`):
```javascript
test('Sign up creates account and sends email', async ({ page }) => {
  await page.goto('/title/Sign%20Up')

  await page.fill('[name="username"]', 'e2e_test_' + Date.now())
  await page.fill('[name="pass"]', 'testpassword123')
  await page.fill('[name="pass_hash"]', 'testpassword123')
  await page.fill('[name="email"]', 'test@example.com')
  await page.fill('[name="email_hash"]', 'test@example.com')

  await page.click('[name="beseech"]')

  // Verify success message
  await expect(page.locator('h3')).toContainText('Welcome to Everything2')

  // TODO: Verify email was sent (check logs or SES)
})
```

**Email Delivery Testing**:
1. **Development**: Check `development.log` for email content
2. **Staging**: Use SES sandbox, verify email in verified inbox
3. **Production**: Test with real email (use personal account)

#### Risks

**Moderate Risk**:
- Email delivery is critical for user acquisition
- reCAPTCHA integration must work correctly
- Security validations must be preserved exactly

**Mitigation**:
- Comprehensive testing before deployment
- Gradual rollout (A/B test React vs Mason)
- Keep Mason template as fallback during migration

---

## Migration Priorities

### Immediate (This Session)
✅ **maintenance_display.mc** - COMPLETE

### Next Steps (Future Sessions)

**Priority 1**: **Full-Text Search** (Low Risk, 1-2 hours)
- Simple React port
- No database impact
- No security concerns

**Priority 2**: **Sign Up Page** (Moderate Risk, 8-10 hours)
- Create API endpoint
- Implement email testing infrastructure
- Build React form with reCAPTCHA
- Comprehensive E2E testing

---

## Success Criteria

### Full-Text Search
- [ ] React component loads Google CSE
- [ ] Search form submits correctly
- [ ] Results render in iframe
- [ ] Mason template deleted

### Sign Up
- [ ] Form validates all fields correctly
- [ ] reCAPTCHA v3 integration works
- [ ] Email hashing matches server-side
- [ ] Activation emails send via SES
- [ ] E2E test covers full flow
- [ ] Email delivery verified in dev/staging
- [ ] Mason template deleted

### Final Cleanup
- [ ] All Mason2 page templates removed
- [ ] `templates/pages/` directory empty or minimal
- [ ] Phase 3 (Mason2 elimination) complete
- [ ] Documentation updated

---

## Timeline Estimate

- **Full-Text Search**: 1-2 hours
- **Sign Up Infrastructure**: 3-4 hours (email testing, API)
- **Sign Up Implementation**: 4-5 hours (React, validation)
- **Testing & Verification**: 2-3 hours
- **Total**: **10-14 hours** spread across 2-3 sessions

---

## Next Actions

**For User**:
1. Review migration strategies
2. Confirm email testing approach
3. Decide if SES sandbox setup is needed
4. Approve proceeding with Full-Text Search migration

**For Implementation**:
1. Start with Full-Text Search (low risk)
2. Build email testing infrastructure for Sign Up
3. Implement Sign Up API endpoint
4. Create React Sign Up component
5. Delete Mason templates when verified

