# Halloween Costume System

## Overview

The Halloween Costume System allows users to temporarily change their display name during the Halloween period. Users can purchase a "costume" (an alternate display name) that appears in the Other Users nodelet and chatterbox instead of their real username.

## Active Period

The Halloween system is active from **October 25 through November 2** each year. This gives users time to:
- Purchase costumes before Halloween
- Enjoy costumes on Halloween night (October 31)
- Continue wearing costumes for a couple days after

### Testing Override

For development and testing, set `force_halloween_mode` to `1` in the configuration:

```json
{
  "force_halloween_mode": 1
}
```

This overrides the date check and enables all Halloween features regardless of the current date.

## User Features

### The Costume Shop (`/title/The Costume Shop`)

- **Location**: Accessible year-round, but only functional during Halloween period
- **Cost**: 30 GP (free for admins)
- **Restrictions**:
  - Maximum 40 characters
  - Cannot use `[ ] < > &` characters
  - Cannot use an existing username as a costume name
  - One costume per user at a time

### What Costumes Change

1. **Other Users Nodelet**: Your costume name appears instead of your username
2. **Chatterbox**: Messages show your costume name with a pipe link (`username|costume`)
3. **Links still work**: Clicking the costume name still links to your actual user profile

### What Costumes Don't Change

- Your homenode/profile page title
- Your byline on writeups
- Your name in messages
- Search results
- Any administrative functions

## Staff Features

### Costume Remover (`/title/Costume Remover`)

Editors can remove abusive costumes from users:
- Sends an automatic Klaproth message warning the user
- Logs the removal for moderation tracking

## Technical Implementation

### Data Storage

Costumes are stored in the user's VARS:

```perl
$VARS->{costume} = "Spooky Ghost";  # The costume display name
$VARS->{treats} = 0;                # Reset on costume purchase (legacy)
```

### Key Files

| File | Purpose |
|------|---------|
| `ecore/Everything/Application.pm` | `inHalloweenPeriod()` - centralized date check |
| `ecore/Everything/Page/the_costume_shop.pm` | Costume Shop page |
| `ecore/Everything/API/costumes.pm` | Buy/remove costume endpoints |
| `ecore/Everything/Page/costume_remover.pm` | Editor costume removal tool |
| `react/components/Documents/TheCostumeShop.js` | React frontend |
| `react/components/Documents/CostumeRemover.js` | React costume remover |

### API Endpoints

#### POST `/api/costumes/buy`

Purchase a costume.

**Request:**
```json
{
  "costume": "Spooky Ghost"
}
```

**Response:**
```json
{
  "success": 1,
  "message": "You're now dressed as \"Spooky Ghost\"!",
  "newCostume": "Spooky Ghost",
  "newGP": 70
}
```

**Errors:**
- Shop is closed (not Halloween period)
- Costume name empty or too long
- Costume name conflicts with existing username
- Not enough GP

#### POST `/api/costumes/remove`

Remove a user's costume (editors only).

**Request:**
```json
{
  "username": "baduser"
}
```

**Response:**
```json
{
  "success": 1,
  "message": "Removed costume \"Bad Costume\" from baduser",
  "username": "baduser",
  "oldCostume": "Bad Costume"
}
```

### Display Logic

In `buildOtherUsersData()` (Application.pm):

```perl
my $costume_name = $other_uservars->{costume};
if($costume_name && $this->inHalloweenPeriod()) {
  $displayUser = { title => $costume_name };
}
```

In chatterbox formatting (htmlcode.pm):

```perl
if (htmlcode('isSpecialDate','halloween')) {
  my $costume = getVars($aUser)->{costume};
  if ($costume gt '') {
    my $halloweenStr = $$aUser{title}."|".$APP->encodeHTML($costume);
    $userLink = linkNodeTitle($halloweenStr);
  }
}
```

## Configuration

### Everything::Configuration

```perl
# Halloween mode testing - set to 1 to force Halloween features regardless of date
has 'force_halloween_mode' => (isa => 'Bool', is => 'ro', default => 0);
```

### JSON Config Example

```json
{
  "force_halloween_mode": false
}
```

## History

The costume system was one of E2's earliest seasonal features. Originally implemented entirely in Perl embedded in database nodes, it was migrated to:

1. Perl Page/API classes (December 2025)
2. React frontend components (December 2025)
3. Centralized `inHalloweenPeriod()` method (January 2026)

## Related Features

- **isSpecialDate htmlcode**: Legacy date checker for various holidays
- **Treats system**: Legacy Halloween treat-or-trick system (partially deprecated)
