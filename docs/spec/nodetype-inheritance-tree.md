# Everything2 Nodetype Inheritance Tree

This document maps the complete nodetype inheritance hierarchy (node IDs, `extends_nodetype`, and `sqltable`).

**Last Updated**: 2026-06-15

> **Note on the controller labels below.** The "React Controller" / "No Controller" annotations are a historical snapshot of the React-migration state and are *not* the authoritative source — re-derive from `ecore/Everything/Controller/*` and `ecore/Everything/Page/*` if you need current status. The old framing they referenced is gone: `Everything::Delegation::htmlpage` and the `page_header` / `page_actions` htmlcodes **no longer exist**, and tickers are now `Everything::Page` classes (no "legacy htmlpage fallback"). What remains durably accurate in this document is the **inheritance tree itself** (node IDs / `extends_nodetype` / `sqltable`).

## Legend

- **React Controller** - Type has a controller that sets `reactPageMode = \1`
- **Inherits Controller** - Type's controller extends another controller (inherits its behavior)
- **No Controller** - Type has no dedicated controller class

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
│   │   ├── ticker (1252389) - Page classes (Everything::Page)
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
│   ├── e2client (1261857) - React Controller
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
│   │   └── debatecomment (1156105) - React Controller
│   │       └── sqltable: debatecomment
│   │       └── debate (1157413) - Inherits Controller (extends debatecomment) → React
│   ├── usergroup (16) - React Controller
│   │   └── sqltable: document
│   │   └── collaboration (1254859) - React Controller
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
├── podcast (1957956) - React Controller
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
recording (1957954) - React Controller
    └── sqltable: recording
license (1981775) - No Controller
publication_status (2035423) - No Controller
feedback_policy (2116371) - No Controller
datastash (2117441) - React Controller
    └── sqltable: setting
```

## Document-Inheriting Types Summary

These types include the `document` sqltable (either directly or through inheritance):

| Type | Node ID | Controller Status | Notes |
|------|---------|-------------------|-------|
| document | 3 | React | Base document type |
| superdoc | 14 | React | Extends document |
| restricted_superdoc | 13 | React (via superdoc) | Extends superdoc |
| superdocnolinks | 1065266 | React (via superdoc) | Extends superdoc |
| oppressor_superdoc | 1144104 | React (via superdoc) | Extends superdoc |
| fullpage | 451267 | React | Extends superdoc |
| ticker | 1252389 | Page classes | Rendered by `Everything::Page` classes |
| e2poll | 1685242 | React | Extends superdoc |
| schema | 1258942 | React | Extends ticker |
| draft | 2035430 | React | Extends document |
| writeup | 117 | React | Extends draft |
| mail | 154 | React | Extends document |
| room | 545241 | React | Extends document |
| edevdoc | 854232 | React (via document) | Extends document |
| node_forward | 1147470 | Legacy (redirect) | HTTP redirect, no content |
| e2client | 1261857 | React | Extends document |
| sustype | 1399991 | **No Controller** | Extends document |
| stylesheet | 1854352 | React | Extends document |
| registry | 1876758 | **No Controller** | Extends document |
| oppressor_document | 1983713 | React (via document) | Extends document |
| writeup_feedback | 2116380 | **No Controller** | Extends document |
| user | 15 | React | Has document in sqltable |
| usergroup | 16 | React | Has document sqltable |
| collaboration | 1254859 | React | Extends usergroup |
| category | 1522375 | React | Has document sqltable |

## Types Without React Controllers

These types have no dedicated controller class:

### No Controller at All
- **sustype** (1399991) - Extends document
- **registry** (1876758) - Extends document
- **writeup_feedback** (2116380) - Extends document
- **opcode** (415056) - Extends htmlcode
- **writeuptype** (118) - Standalone
- **linktype** (169632) - Standalone
- **status** (1288633) - Standalone
- **ticket_type** (1946032) - Standalone
- **license** (1981775) - Standalone
- **publication_status** (2035423) - Standalone
- **feedback_policy** (2116371) - Standalone
- **useraction** (2032071) - Extends node

### Has Controller But Special Behavior
- **ticker** (1252389) - Controller delegates to Page classes; all tickers currently have Page classes
- **jsonexport** (2100759) - Legacy controller for JSON exports
- **node_forward** (1147470) - Does HTTP redirect, never renders page content

## Types Still Lacking a Dedicated Controller Class

The following document-inheriting types have no dedicated controller class and are the main remaining gaps if a uniform per-type controller surface is ever desired:

1. sustype
2. registry
3. writeup_feedback
4. Various standalone metadata types (if they need display pages)

(The legacy `page_header` / `page_actions` / `weblogform` / `categoryform` htmlcode plumbing that this section previously described no longer exists, so there is no longer a "legacy fallback render path" to deprecate.)
