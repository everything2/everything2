# Everything2 Nodetype Inheritance Tree

This document maps the complete nodetype inheritance hierarchy and indicates whether each type is handled by a React-enabled controller or falls back to legacy delegation.

**Last Updated**: 2026-01-07

## Legend

- **React Controller** - Type has a controller that sets `reactPageMode = \1`, bypassing legacy `page_header`/`page_actions`
- **Legacy Delegation** - Type falls back to legacy htmlpage delegation system
- **Inherits Controller** - Type's controller extends another controller (inherits its behavior)
- **No Controller** - Type has no dedicated controller, uses legacy system entirely

## Inheritance Tree

### Root: node (id: 7)

The base type that all nodetypes ultimately inherit from. Has no sqltable of its own.

```
node (7) - No Controller (base type, handled specially)
├── nodetype (1) - No Controller
├── container (2) - React Controller
│   └── sqltable: container
├── document (3) - React Controller
│   └── sqltable: document
│   ├── superdoc (14) - React Controller (extends page)
│   │   ├── restricted_superdoc (13) - Inherits Controller (extends superdoc) → React
│   │   ├── superdocnolinks (1065266) - Inherits Controller (extends superdoc) → React
│   │   ├── oppressor_superdoc (1144104) - Inherits Controller (extends superdoc) → React
│   │   ├── fullpage (451267) - React Controller (extends page)
│   │   ├── ticker (1252389) - Legacy (falls back when no Page class)
│   │   │   └── schema (1258942) - React Controller
│   │   │       └── sqltable: e2schema
│   │   └── e2poll (1685242) - React Controller
│   │       └── sqltable: e2poll
│   ├── draft (2035430) - React Controller
│   │   └── sqltable: draft
│   │   └── writeup (117) - React Controller
│   │       └── sqltable: writeup
│   ├── mail (154) - React Controller
│   │   └── sqltable: mail
│   ├── room (545241) - React Controller
│   │   └── sqltable: roomdata
│   ├── edevdoc (854232) - Inherits Controller (extends document) → React
│   ├── node_forward (1147470) - Legacy Controller (HTTP redirect, no page content)
│   ├── e2client (1261857) - No Controller
│   │   └── sqltable: e2client
│   ├── sustype (1399991) - No Controller
│   ├── stylesheet (1854352) - React Controller
│   │   └── sqltable: s3content
│   ├── registry (1876758) - No Controller
│   │   └── sqltable: registry
│   ├── oppressor_document (1983713) - Inherits Controller (extends document) → React
│   └── writeup_feedback (2116380) - No Controller
│       └── sqltable: writeup_feedback
├── htmlcode (4) - React Controller
│   └── sqltable: htmlcode
│   ├── opcode (415056) - No Controller
│   └── jsonexport (2100759) - Legacy Controller
├── htmlpage (5) - React Controller
│   └── sqltable: htmlpage (implicit)
├── nodegroup (8) - No Controller
│   ├── e2node (116) - React Controller
│   │   └── sqltable: e2node
│   │   └── debatecomment (1156105) - No Controller
│   │       └── sqltable: debatecomment
│   │       └── debate (1157413) - No Controller
│   ├── usergroup (16) - React Controller
│   │   └── sqltable: document
│   │   └── collaboration (1254859) - No Controller
│   │       └── sqltable: collaboration
│   └── category (1522375) - React Controller
│       └── sqltable: document
├── nodelet (9) - React Controller
│   └── sqltable: nodelet
├── user (15) - React Controller
│   └── sqltable: user,setting,document
├── dbtable (148) - React Controller
├── maintenance (150) - React Controller
│   └── sqltable: htmlcode,maintenance
├── setting (153) - React Controller
│   └── sqltable: setting
├── achievement (1917847) - React Controller
│   └── sqltable: achievement
├── notification (1930710) - React Controller
│   └── sqltable: notification
├── podcast (1957956) - No Controller
│   └── sqltable: podcast
└── useraction (2032071) - No Controller
```

### Standalone Types (no extends_nodetype)

These types don't extend any other nodetype:

```
writeuptype (118) - No Controller
linktype (169632) - No Controller
status (1288633) - No Controller
    └── sqltable: status
ticket_type (1946032) - No Controller
recording (1957954) - No Controller
    └── sqltable: recording
license (1981775) - No Controller
publication_status (2035423) - No Controller
feedback_policy (2116371) - No Controller
datastash (2117441) - React Controller
    └── sqltable: setting
```

## Document-Inheriting Types Summary

These types include the `document` sqltable (either directly or through inheritance) and are relevant for features like weblogform that check `sqltablelist =~ /document/`:

| Type | Node ID | Controller Status | Notes |
|------|---------|-------------------|-------|
| document | 3 | React | Base document type |
| superdoc | 14 | React | Extends document |
| restricted_superdoc | 13 | React (via superdoc) | Extends superdoc |
| superdocnolinks | 1065266 | React (via superdoc) | Extends superdoc |
| oppressor_superdoc | 1144104 | React (via superdoc) | Extends superdoc |
| fullpage | 451267 | React | Extends superdoc |
| ticker | 1252389 | **Legacy fallback** | Falls back when no Page class |
| e2poll | 1685242 | React | Extends superdoc |
| schema | 1258942 | React | Extends ticker |
| draft | 2035430 | React | Extends document |
| writeup | 117 | React | Extends draft |
| mail | 154 | React | Extends document |
| room | 545241 | React | Extends document |
| edevdoc | 854232 | React (via document) | Extends document |
| node_forward | 1147470 | Legacy (redirect) | HTTP redirect, no content |
| e2client | 1261857 | **No Controller** | Extends document |
| sustype | 1399991 | **No Controller** | Extends document |
| stylesheet | 1854352 | React | Extends document |
| registry | 1876758 | **No Controller** | Extends document |
| oppressor_document | 1983713 | React (via document) | Extends document |
| writeup_feedback | 2116380 | **No Controller** | Extends document |
| user | 15 | React | Has document in sqltable |
| usergroup | 16 | React | Has document sqltable |
| collaboration | 1254859 | **No Controller** | Extends usergroup |
| category | 1522375 | React | Has document sqltable |

## Types Without React Controllers

These types may still use legacy `page_header`/`page_actions`:

### No Controller at All
- **e2client** (1261857) - Extends document
- **sustype** (1399991) - Extends document
- **registry** (1876758) - Extends document
- **writeup_feedback** (2116380) - Extends document
- **collaboration** (1254859) - Extends usergroup
- **debatecomment** (1156105) - Extends e2node
- **debate** (1157413) - Extends debatecomment
- **opcode** (415056) - Extends htmlcode
- **writeuptype** (118) - Standalone
- **linktype** (169632) - Standalone
- **status** (1288633) - Standalone
- **ticket_type** (1946032) - Standalone
- **recording** (1957954) - Standalone
- **podcast** (1957956) - Extends node
- **license** (1981775) - Standalone
- **publication_status** (2035423) - Standalone
- **feedback_policy** (2116371) - Standalone
- **useraction** (2032071) - Extends node

### Has Controller But Falls Back to Legacy
- **ticker** (1252389) - Controller checks for Page class, falls back to delegation if none exists
- **jsonexport** (2100759) - Legacy controller for JSON exports
- **node_forward** (1147470) - Does HTTP redirect, never renders page content

## Implications for Legacy Code Removal

### weblogform / categoryform
These htmlcodes in `page_actions` check `$$NODE{type}{sqltablelist} =~ /document/`. They could still be reached by:
- **ticker** nodes without dedicated Page classes
- **e2client**, **sustype**, **registry**, **writeup_feedback** nodes (no controllers)
- **collaboration** nodes (no controller, inherits document via usergroup)

### page_actions
The `page_actions` htmlcode is called from `page_header` which is part of the legacy container system. It's still reachable for any document-inheriting type without a React controller.

## Migration Status

- **Fully migrated**: 21 types have React controllers
- **Partially migrated**: 3 types have controllers but may fall back
- **Not migrated**: 18+ types have no controller and use legacy system

To fully deprecate legacy `page_actions` features like `weblogform`, controllers would need to be created for:
1. ticker (or ensure all tickers have Page classes)
2. e2client
3. sustype
4. registry
5. writeup_feedback
6. collaboration
7. debatecomment/debate
8. Various standalone metadata types (if they need display pages)
