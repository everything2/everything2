# Everything2 Nodetype Inheritance Tree

This document maps the complete nodetype inheritance hierarchy (node IDs, `extends_nodetype`, and `sqltable`).

**Last Updated**: 2026-11-16
**Last verified: 2026-11-16** against `nodepack/nodetype/*.xml`, the dev DB `nodetype` table, and `ecore/Everything/Controller/*.pm`.

> **Controller labels.** "Controller" means a class `Everything::Controller::<type>` exists in `ecore/Everything/Controller/`. Most extend `Everything::Controller` directly; exceptions are noted (e.g. `superdoc`/`fullpage` extend `Everything::Controller::page`, which dispatches by title to `Everything::Page::*`; `ticker`/`jsonexport` also dispatch by title to `Everything::Page::*`). Controller inheritance does **not** follow nodetype inheritance automatically. Re-derive from the directory if in doubt.
>
> **Removed types.** `htmlpage` (5) was removed (`b834dc845`) and `opcode` (415056) was removed with the opcode delegation teardown (`f0fdac976`, #4335). Neither has a nodetype XML or a dev DB row any more. `Everything::Delegation::htmlpage` and the `page_header`/`page_actions` htmlcodes are also gone.

## Legend

- **Controller** - Has its own `Everything::Controller::<type>` class
- **Controller (→ X)** - Its controller class extends `Everything::Controller::X`
- **No Controller** - No dedicated controller class

## Inheritance Tree

### Root: node (id: 7)

The base type that all nodetypes ultimately inherit from. Has no sqltable of its own (`extends_nodetype` 0).

```
node (7) - No Controller (base type, handled specially)
├── container (2) - Controller
│   └── sqltable: container
├── document (3) - Controller
│   ├── sqltable: document
│   ├── superdoc (14) - Controller (→ page)
│   │   ├── restricted_superdoc (13) - Controller (→ superdoc)
│   │   ├── superdocnolinks (1065266) - Controller (→ superdoc)
│   │   ├── oppressor_superdoc (1144104) - Controller (→ superdoc)
│   │   ├── fullpage (451267) - Controller (→ page)
│   │   ├── ticker (1252389) - Controller (title → Everything::Page::*)
│   │   │   └── schema (1258942) - Controller
│   │   │       └── sqltable: e2schema
│   │   └── e2poll (1685242) - Controller
│   │       └── sqltable: e2poll
│   ├── draft (2035430) - Controller
│   │   ├── sqltable: draft
│   │   └── writeup (117) - Controller
│   │       └── sqltable: writeup
│   ├── mail (154) - Controller
│   │   └── sqltable: mail
│   ├── room (545241) - Controller
│   │   └── sqltable: roomdata
│   ├── edevdoc (854232) - Controller (→ document)
│   ├── node_forward (1147470) - Controller (HTTP redirect, no page content)
│   ├── e2client (1261857) - Controller
│   │   └── sqltable: e2client
│   ├── sustype (1399991) - No Controller
│   ├── stylesheet (1854352) - Controller
│   │   └── sqltable: s3content
│   ├── registry (1876758) - Controller
│   │   └── sqltable: registry
│   ├── oppressor_document (1983713) - Controller (→ document)
│   └── writeup_feedback (2116380) - No Controller
│       └── sqltable: writeup_feedback
├── htmlcode (4) - Controller
│   ├── sqltable: htmlcode
│   └── jsonexport (2100759) - Controller (title → Everything::Page::*)
├── nodegroup (8) - Controller
│   ├── e2node (116) - Controller
│   │   └── sqltable: e2node
│   ├── debatecomment (1156105) - Controller
│   │   ├── sqltable: debatecomment
│   │   └── debate (1157413) - Controller (→ debatecomment)
│   ├── usergroup (16) - Controller
│   │   ├── sqltable: document
│   │   └── collaboration (1254859) - Controller
│   │       └── sqltable: collaboration
│   └── category (1522375) - Controller
│       └── sqltable: document
├── nodelet (9) - Controller
│   └── sqltable: nodelet
├── user (15) - Controller
│   └── sqltable: user,setting,document
├── dbtable (148) - Controller
├── maintenance (150) - Controller
│   └── sqltable: htmlcode,maintenance
├── setting (153) - Controller
│   └── sqltable: setting
├── achievement (1917847) - Controller
│   └── sqltable: achievement
├── notification (1930710) - Controller
│   └── sqltable: notification
├── podcast (1957956) - Controller
│   └── sqltable: podcast
└── useraction (2032071) - No Controller
```

Note: `debatecomment` extends `nodegroup` (8) directly, not `e2node`.

### Standalone Types (extends_nodetype = 0)

```
nodetype (1) - Controller
    └── sqltable: nodetype
writeuptype (118) - No Controller
linktype (169632) - No Controller
status (1288633) - No Controller
    └── sqltable: status
ticket_type (1946032) - No Controller
recording (1957954) - Controller
    └── sqltable: recording
license (1981775) - No Controller
publication_status (2035423) - No Controller
feedback_policy (2116371) - No Controller
datastash (2117441) - Controller
    └── sqltable: setting
```

## Document-Inheriting Types Summary

These types include the `document` sqltable (either directly or through inheritance):

| Type | Node ID | Controller | Notes |
|------|---------|------------|-------|
| document | 3 | Yes | Base document type |
| superdoc | 14 | Yes (→ page) | Extends document |
| restricted_superdoc | 13 | Yes (→ superdoc) | Extends superdoc |
| superdocnolinks | 1065266 | Yes (→ superdoc) | Extends superdoc |
| oppressor_superdoc | 1144104 | Yes (→ superdoc) | Extends superdoc |
| fullpage | 451267 | Yes (→ page) | Extends superdoc |
| ticker | 1252389 | Yes | Extends superdoc; rendered by `Everything::Page` classes |
| e2poll | 1685242 | Yes | Extends superdoc |
| schema | 1258942 | Yes | Extends ticker |
| draft | 2035430 | Yes | Extends document |
| writeup | 117 | Yes | Extends draft |
| mail | 154 | Yes | Extends document |
| room | 545241 | Yes | Extends document |
| edevdoc | 854232 | Yes (→ document) | Extends document |
| node_forward | 1147470 | Yes (redirect) | HTTP redirect, no content |
| e2client | 1261857 | Yes | Extends document |
| sustype | 1399991 | **No** | Extends document |
| stylesheet | 1854352 | Yes | Extends document |
| registry | 1876758 | Yes | Extends document |
| oppressor_document | 1983713 | Yes (→ document) | Extends document |
| writeup_feedback | 2116380 | **No** | Extends document |
| user | 15 | Yes | Has document in sqltable |
| usergroup | 16 | Yes | Has document sqltable (extends nodegroup) |
| collaboration | 1254859 | Yes | Extends usergroup |
| category | 1522375 | Yes | Has document sqltable (extends nodegroup) |

## Types Without a Controller Class

- **sustype** (1399991) - Extends document
- **writeup_feedback** (2116380) - Extends document
- **useraction** (2032071) - Extends node
- **writeuptype** (118), **linktype** (169632), **status** (1288633), **ticket_type** (1946032), **license** (1981775), **publication_status** (2035423), **feedback_policy** (2116371) - Standalone metadata types

### Controllers With Special Behavior
- **ticker** (1252389) / **jsonexport** (2100759) - Dispatch by node title to `Everything::Page::*` classes
- **superdoc** / **fullpage** - Extend `Everything::Controller::page`, which maps title → `Everything::Page::*` (falls back to `Everything::Page::_unimplemented`)
- **node_forward** (1147470) - Does HTTP redirect, never renders page content
