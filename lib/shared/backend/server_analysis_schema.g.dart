// Backend b95cff51; regenerate with tool/project_server_analysis_contract.mjs.
const serverAnalysisSchemaJson = r'''
{
  "AnalysisRequest": {
    "properties": {
      "items": {
        "items": {
          "$ref": "#/components/schemas/AnalysisCommand"
        },
        "type": "array",
        "maxItems": 50,
        "minItems": 1,
        "title": "Items"
      }
    },
    "additionalProperties": false,
    "type": "object",
    "required": [
      "items"
    ],
    "title": "AnalysisRequest"
  },
  "AnalysisResponse": {
    "properties": {
      "evaluated_at": {
        "type": "string",
        "format": "date-time",
        "title": "Evaluated At"
      },
      "items": {
        "items": {
          "$ref": "#/components/schemas/AnalysisItem"
        },
        "type": "array",
        "maxItems": 50,
        "minItems": 1,
        "title": "Items"
      }
    },
    "additionalProperties": false,
    "type": "object",
    "required": [
      "evaluated_at",
      "items"
    ],
    "title": "AnalysisResponse"
  },
  "RoleAnalysis": {
    "properties": {
      "version": {
        "type": "integer",
        "minimum": 1,
        "title": "Version"
      },
      "saved_at": {
        "anyOf": [
          {
            "type": "string",
            "format": "date-time"
          },
          {
            "type": "null"
          }
        ],
        "title": "Saved At"
      },
      "summary": {
        "anyOf": [
          {
            "$ref": "#/components/schemas/RoleSummary"
          },
          {
            "type": "null"
          }
        ]
      },
      "detail": {
        "anyOf": [
          {
            "$ref": "#/components/schemas/AnalysisDetail"
          },
          {
            "type": "null"
          }
        ]
      }
    },
    "additionalProperties": false,
    "type": "object",
    "required": [
      "version",
      "saved_at",
      "summary",
      "detail"
    ],
    "title": "RoleAnalysis"
  },
  "AnalysisDetail": {
    "properties": {
      "detection": {
        "$ref": "#/components/schemas/Detection"
      },
      "rune_count": {
        "type": "integer",
        "minimum": 0,
        "title": "Rune Count"
      },
      "equipped_gem_count": {
        "anyOf": [
          {
            "type": "integer",
            "minimum": 0
          },
          {
            "type": "null"
          }
        ],
        "title": "Equipped Gem Count"
      },
      "gem_effects_source_available": {
        "type": "boolean",
        "title": "Gem Effects Source Available"
      },
      "gems": {
        "items": {
          "$ref": "#/components/schemas/Gem"
        },
        "type": "array",
        "title": "Gems"
      },
      "ark_grid_core_points": {
        "items": {
          "$ref": "#/components/schemas/GridCore"
        },
        "type": "array",
        "title": "Ark Grid Core Points"
      },
      "ark_grid_conditions": {
        "items": {
          "$ref": "#/components/schemas/GridCondition"
        },
        "type": "array",
        "title": "Ark Grid Conditions"
      },
      "ark_grid_minimum": {
        "anyOf": [
          {
            "$ref": "#/components/schemas/GridMinimum"
          },
          {
            "type": "null"
          }
        ]
      },
      "notices": {
        "items": {
          "$ref": "#/components/schemas/Notice"
        },
        "type": "array",
        "title": "Notices"
      }
    },
    "additionalProperties": false,
    "type": "object",
    "required": [
      "detection",
      "rune_count",
      "equipped_gem_count",
      "gem_effects_source_available",
      "gems",
      "ark_grid_core_points",
      "ark_grid_conditions",
      "ark_grid_minimum",
      "notices"
    ],
    "title": "AnalysisDetail"
  },
  "BPowerComparison": {
    "properties": {
      "selected_role": {
        "type": "string",
        "enum": [
          "dealer",
          "support"
        ],
        "title": "Selected Role"
      },
      "requirement": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 32,
            "minLength": 1,
            "pattern": "^[0-9]+(?:\\.[0-9]+)?$"
          },
          {
            "type": "null"
          }
        ],
        "title": "Requirement"
      },
      "actual": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 32,
            "minLength": 1,
            "pattern": "^[0-9]+(?:\\.[0-9]+)?$"
          },
          {
            "type": "null"
          }
        ],
        "title": "Actual"
      },
      "state": {
        "type": "string",
        "enum": [
          "unrestricted",
          "missing",
          "below",
          "meets"
        ],
        "title": "State"
      },
      "source": {
        "type": "string",
        "const": "server_analysis",
        "title": "Source"
      },
      "trust": {
        "type": "string",
        "const": "server_computed",
        "title": "Trust"
      },
      "summary_version": {
        "type": "integer",
        "maximum": 2147483647,
        "minimum": 1,
        "title": "Summary Version"
      },
      "observed_at": {
        "anyOf": [
          {
            "type": "string",
            "format": "date-time"
          },
          {
            "type": "null"
          }
        ],
        "title": "Observed At"
      },
      "saved_at": {
        "anyOf": [
          {
            "type": "string",
            "format": "date-time"
          },
          {
            "type": "null"
          }
        ],
        "title": "Saved At"
      },
      "integrity_status": {
        "anyOf": [
          {
            "type": "string",
            "enum": [
              "clean",
              "review",
              "error",
              "unavailable"
            ]
          },
          {
            "type": "null"
          }
        ],
        "title": "Integrity Status"
      },
      "issues": {
        "items": {
          "$ref": "#/components/schemas/BAnalysisIssue"
        },
        "type": "array",
        "title": "Issues"
      }
    },
    "additionalProperties": false,
    "type": "object",
    "required": [
      "selected_role",
      "requirement",
      "actual",
      "state",
      "source",
      "trust",
      "summary_version",
      "observed_at",
      "saved_at",
      "integrity_status",
      "issues"
    ],
    "title": "BPowerComparison"
  },
  "CandidatePower": {
    "properties": {
      "value": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 64,
            "minLength": 1,
            "pattern": "^[0-9]+(?:\\.[0-9]+)?$"
          },
          {
            "type": "null"
          }
        ],
        "title": "Value"
      },
      "source": {
        "type": "string",
        "enum": [
          "server_analysis",
          "unavailable",
          "not_disclosed"
        ],
        "title": "Source"
      },
      "trust": {
        "anyOf": [
          {
            "type": "string",
            "const": "server_computed"
          },
          {
            "type": "null"
          }
        ],
        "title": "Trust"
      },
      "observed_at": {
        "anyOf": [
          {
            "type": "string",
            "format": "date-time"
          },
          {
            "type": "null"
          }
        ],
        "title": "Observed At"
      },
      "saved_at": {
        "anyOf": [
          {
            "type": "string",
            "format": "date-time"
          },
          {
            "type": "null"
          }
        ],
        "title": "Saved At"
      },
      "summary_version": {
        "anyOf": [
          {
            "type": "integer",
            "minimum": 1
          },
          {
            "type": "null"
          }
        ],
        "title": "Summary Version"
      },
      "integrity_status": {
        "anyOf": [
          {
            "type": "string",
            "enum": [
              "clean",
              "review",
              "error",
              "unavailable"
            ]
          },
          {
            "type": "null"
          }
        ],
        "title": "Integrity Status"
      },
      "issues": {
        "items": {
          "$ref": "#/components/schemas/AnalysisIssue"
        },
        "type": "array",
        "title": "Issues"
      }
    },
    "additionalProperties": false,
    "type": "object",
    "required": [
      "value",
      "source",
      "trust",
      "observed_at",
      "saved_at",
      "summary_version",
      "integrity_status",
      "issues"
    ],
    "title": "CandidatePower"
  },
  "GroupRolePower": {
    "properties": {
      "combat_power": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 32,
            "minLength": 1,
            "pattern": "^[0-9]+(?:\\.[0-9]+)?$"
          },
          {
            "type": "null"
          }
        ],
        "title": "Combat Power"
      },
      "source": {
        "type": "string",
        "enum": [
          "server_analysis",
          "unavailable"
        ],
        "title": "Source"
      },
      "trust": {
        "anyOf": [
          {
            "type": "string",
            "const": "server_computed"
          },
          {
            "type": "null"
          }
        ],
        "title": "Trust"
      },
      "observed_at": {
        "anyOf": [
          {
            "type": "string",
            "format": "date-time"
          },
          {
            "type": "null"
          }
        ],
        "title": "Observed At"
      },
      "saved_at": {
        "anyOf": [
          {
            "type": "string",
            "format": "date-time"
          },
          {
            "type": "null"
          }
        ],
        "title": "Saved At"
      },
      "summary_version": {
        "anyOf": [
          {
            "type": "integer",
            "minimum": 1
          },
          {
            "type": "null"
          }
        ],
        "title": "Summary Version"
      },
      "issues": {
        "items": {
          "$ref": "#/components/schemas/AnalysisIssue"
        },
        "type": "array",
        "title": "Issues"
      },
      "analysis": {
        "anyOf": [
          {
            "$ref": "#/components/schemas/GroupAnalysis"
          },
          {
            "type": "null"
          }
        ]
      },
      "reason": {
        "anyOf": [
          {
            "type": "string",
            "enum": [
              "ROLE_ANALYSIS_UNAVAILABLE",
              "ROLE_ANALYSIS_INVALID"
            ]
          },
          {
            "type": "null"
          }
        ],
        "title": "Reason"
      }
    },
    "additionalProperties": false,
    "type": "object",
    "required": [
      "combat_power",
      "source",
      "trust",
      "observed_at",
      "saved_at",
      "summary_version",
      "issues",
      "analysis",
      "reason"
    ],
    "title": "GroupRolePower"
  },
  "AnalysisCommand": {
    "properties": {
      "command_id": {
        "type": "string",
        "pattern": "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$",
        "format": "uuid",
        "title": "Command Id"
      },
      "character_id": {
        "type": "string",
        "format": "uuid",
        "title": "Character Id"
      },
      "expected_ownership_revision": {
        "type": "integer",
        "maximum": 2147483647,
        "minimum": 1,
        "title": "Expected Ownership Revision"
      },
      "expected_lifecycle_revision": {
        "type": "integer",
        "maximum": 2147483647,
        "minimum": 1,
        "title": "Expected Lifecycle Revision"
      },
      "expected_summary_versions": {
        "$ref": "#/components/schemas/ExpectedVersions"
      },
      "trigger": {
        "type": "string",
        "enum": [
          "automatic",
          "manual"
        ],
        "title": "Trigger"
      }
    },
    "additionalProperties": false,
    "type": "object",
    "required": [
      "command_id",
      "character_id",
      "expected_ownership_revision",
      "expected_lifecycle_revision",
      "expected_summary_versions",
      "trigger"
    ],
    "title": "AnalysisCommand"
  },
  "AnalysisItem": {
    "properties": {
      "command_id": {
        "type": "string",
        "pattern": "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$",
        "format": "uuid",
        "title": "Command Id"
      },
      "character_id": {
        "type": "string",
        "format": "uuid",
        "title": "Character Id"
      },
      "status": {
        "type": "integer",
        "title": "Status"
      },
      "state": {
        "type": "string",
        "enum": [
          "saved",
          "skipped",
          "failed",
          "not_processed",
          "in_progress",
          "unknown"
        ],
        "title": "State"
      },
      "detected_role": {
        "anyOf": [
          {
            "type": "string",
            "enum": [
              "dealer",
              "support"
            ]
          },
          {
            "type": "null"
          }
        ],
        "title": "Detected Role"
      },
      "retry": {
        "type": "string",
        "enum": [
          "none",
          "same_command",
          "new_command"
        ],
        "title": "Retry"
      },
      "result": {
        "anyOf": [
          {
            "$ref": "#/components/schemas/AnalysisResult"
          },
          {
            "type": "null"
          }
        ]
      },
      "error": {
        "anyOf": [
          {
            "$ref": "#/components/schemas/AnalysisError"
          },
          {
            "type": "null"
          }
        ]
      }
    },
    "additionalProperties": false,
    "type": "object",
    "required": [
      "command_id",
      "character_id",
      "status",
      "state",
      "detected_role",
      "retry",
      "result",
      "error"
    ],
    "title": "AnalysisItem"
  },
  "RoleSummary": {
    "properties": {
      "source": {
        "type": "string",
        "const": "server_analysis",
        "title": "Source"
      },
      "analysis_rules_version": {
        "type": "string",
        "maxLength": 64,
        "minLength": 1,
        "pattern": "^[A-Za-z0-9._-]+$",
        "title": "Analysis Rules Version"
      },
      "analyzed_at": {
        "type": "string",
        "format": "date-time",
        "title": "Analyzed At"
      },
      "combat_power": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 32,
            "minLength": 1,
            "pattern": "^[0-9]+(?:\\.[0-9]+)?$"
          },
          {
            "type": "null"
          }
        ],
        "title": "Combat Power"
      },
      "item_level": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 32,
            "minLength": 1,
            "pattern": "^[0-9]+(?:\\.[0-9]+)?$"
          },
          {
            "type": "null"
          }
        ],
        "title": "Item Level"
      },
      "combat_power_observed_at": {
        "anyOf": [
          {
            "type": "string",
            "format": "date-time"
          },
          {
            "type": "null"
          }
        ],
        "title": "Combat Power Observed At"
      },
      "item_level_observed_at": {
        "anyOf": [
          {
            "type": "string",
            "format": "date-time"
          },
          {
            "type": "null"
          }
        ],
        "title": "Item Level Observed At"
      },
      "integrity_status": {
        "type": "string",
        "enum": [
          "clean",
          "review",
          "error",
          "unavailable"
        ],
        "title": "Integrity Status"
      },
      "catalog_version": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 64,
            "minLength": 1,
            "pattern": "^[A-Za-z0-9._-]+$"
          },
          {
            "type": "null"
          }
        ],
        "title": "Catalog Version"
      },
      "issues": {
        "items": {
          "$ref": "#/components/schemas/AnalysisIssue"
        },
        "type": "array",
        "maxItems": 20,
        "title": "Issues"
      },
      "observed_lifecycle_revision": {
        "type": "integer",
        "minimum": 1,
        "title": "Observed Lifecycle Revision"
      }
    },
    "additionalProperties": false,
    "type": "object",
    "required": [
      "source",
      "analysis_rules_version",
      "analyzed_at",
      "combat_power",
      "item_level",
      "combat_power_observed_at",
      "item_level_observed_at",
      "integrity_status",
      "catalog_version",
      "issues",
      "observed_lifecycle_revision"
    ],
    "title": "RoleSummary"
  },
  "Detection": {
    "properties": {
      "status": {
        "type": "string",
        "enum": [
          "detected",
          "unsupported_class",
          "branch_not_found",
          "ambiguous"
        ],
        "title": "Status"
      },
      "catalog_version": {
        "type": "string",
        "maxLength": 64,
        "minLength": 1,
        "pattern": "^[A-Za-z0-9._-]+$",
        "title": "Catalog Version"
      },
      "class_id": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 64,
            "minLength": 1,
            "pattern": "^[A-Za-z0-9._-]+$"
          },
          {
            "type": "null"
          }
        ],
        "title": "Class Id"
      },
      "branch_id": {
        "anyOf": [
          {
            "type": "string",
            "maxLength": 64,
            "minLength": 1,
            "pattern": "^[A-Za-z0-9._-]+$"
          },
          {
            "type": "null"
          }
        ],
        "title": "Branch Id"
      },
      "branch_display_name": {
        "anyOf": [
          {
            "type": "string"
          },
          {
            "type": "null"
          }
        ],
        "title": "Branch Display Name"
      },
      "detected_role": {
        "anyOf": [
          {
            "type": "string",
            "enum": [
              "dealer",
              "support"
            ]
          },
          {
            "type": "null"
          }
        ],
        "title": "Detected Role"
      },
      "matched_tier1_node": {
        "anyOf": [
          {
            "type": "string"
          },
          {
            "type": "null"
          }
        ],
        "title": "Matched Tier1 Node"
      },
      "matched_related_nodes": {
        "items": {
          "type": "string"
        },
        "type": "array",
        "title": "Matched Related Nodes"
      }
    },
    "additionalProperties": false,
    "type": "object",
    "required": [
      "status",
      "catalog_version",
      "class_id",
      "branch_id",
      "branch_display_name",
      "detected_role",
      "matched_tier1_node",
      "matched_related_nodes"
    ],
    "title": "Detection"
  },
  "Gem": {
    "properties": {
      "slot": {
        "type": "integer",
        "minimum": 0,
        "title": "Slot"
      },
      "level": {
        "type": "integer",
        "minimum": 0,
        "title": "Level"
      },
      "target": {
        "type": "string",
        "title": "Target"
      },
      "descriptions": {
        "items": {
          "type": "string"
        },
        "type": "array",
        "title": "Descriptions"
      },
      "category": {
        "type": "string",
        "enum": [
          "normal",
          "passive_or_identity",
          "unknown"
        ],
        "title": "Category"
      },
      "validation_status": {
        "type": "string",
        "enum": [
          "verified",
          "same_class_target_unverified",
          "foreign_class",
          "unavailable"
        ],
        "title": "Validation Status"
      }
    },
    "additionalProperties": false,
    "type": "object",
    "required": [
      "slot",
      "level",
      "target",
      "descriptions",
      "category",
      "validation_status"
    ],
    "title": "Gem"
  },
  "GridCore": {
    "properties": {
      "name": {
        "type": "string",
        "title": "Name"
      },
      "grade": {
        "type": "string",
        "title": "Grade"
      },
      "point": {
        "type": "integer",
        "minimum": 0,
        "title": "Point"
      },
      "minimum_point": {
        "type": "integer",
        "minimum": 0,
        "title": "Minimum Point"
      },
      "recommended_point": {
        "type": "integer",
        "minimum": 0,
        "title": "Recommended Point"
      }
    },
    "additionalProperties": false,
    "type": "object",
    "required": [
      "name",
      "grade",
      "point",
      "minimum_point",
      "recommended_point"
    ],
    "title": "GridCore"
  },
  "GridCondition": {
    "properties": {
      "core_name": {
        "type": "string",
        "title": "Core Name"
      },
      "condition_text": {
        "type": "string",
        "title": "Condition Text"
      },
      "required_passive_names": {
        "items": {
          "type": "string"
        },
        "type": "array",
        "title": "Required Passive Names"
      },
      "missing_passive_names": {
        "items": {
          "type": "string"
        },
        "type": "array",
        "title": "Missing Passive Names"
      }
    },
    "additionalProperties": false,
    "type": "object",
    "required": [
      "core_name",
      "condition_text",
      "required_passive_names",
      "missing_passive_names"
    ],
    "title": "GridCondition"
  },
  "GridMinimum": {
    "properties": {
      "order_sun_point": {
        "anyOf": [
          {
            "type": "integer",
            "minimum": 0
          },
          {
            "type": "null"
          }
        ],
        "title": "Order Sun Point"
      },
      "order_moon_point": {
        "anyOf": [
          {
            "type": "integer",
            "minimum": 0
          },
          {
            "type": "null"
          }
        ],
        "title": "Order Moon Point"
      },
      "required_point": {
        "type": "integer",
        "const": 14,
        "title": "Required Point"
      }
    },
    "additionalProperties": false,
    "type": "object",
    "required": [
      "order_sun_point",
      "order_moon_point",
      "required_point"
    ],
    "title": "GridMinimum"
  },
  "Notice": {
    "properties": {
      "code": {
        "type": "string",
        "title": "Code"
      },
      "severity": {
        "type": "string",
        "enum": [
          "info",
          "warning"
        ],
        "title": "Severity"
      },
      "message": {
        "type": "string",
        "title": "Message"
      }
    },
    "additionalProperties": false,
    "type": "object",
    "required": [
      "code",
      "severity",
      "message"
    ],
    "title": "Notice"
  },
  "BAnalysisIssue": {
    "properties": {
      "code": {
        "type": "string",
        "maxLength": 64,
        "minLength": 1,
        "pattern": "^[A-Z0-9_]+$",
        "title": "Code"
      },
      "severity": {
        "$ref": "#/components/schemas/Severity"
      }
    },
    "additionalProperties": false,
    "type": "object",
    "required": [
      "code",
      "severity"
    ],
    "title": "BAnalysisIssue"
  },
  "AnalysisIssue": {
    "properties": {
      "code": {
        "type": "string",
        "maxLength": 64,
        "minLength": 1,
        "pattern": "^[A-Z0-9_]+$",
        "title": "Code"
      },
      "severity": {
        "type": "string",
        "enum": [
          "warning",
          "error"
        ],
        "title": "Severity"
      }
    },
    "additionalProperties": false,
    "type": "object",
    "required": [
      "code",
      "severity"
    ],
    "title": "AnalysisIssue"
  },
  "GroupAnalysis": {
    "properties": {
      "version": {
        "type": "integer",
        "minimum": 1,
        "title": "Version"
      },
      "saved_at": {
        "type": "string",
        "format": "date-time",
        "title": "Saved At"
      },
      "analyzed_at": {
        "type": "string",
        "format": "date-time",
        "title": "Analyzed At"
      },
      "integrity_status": {
        "type": "string",
        "enum": [
          "clean",
          "review",
          "error",
          "unavailable"
        ],
        "title": "Integrity Status"
      },
      "issues": {
        "items": {
          "$ref": "#/components/schemas/AnalysisIssue"
        },
        "type": "array",
        "title": "Issues"
      }
    },
    "additionalProperties": false,
    "type": "object",
    "required": [
      "version",
      "saved_at",
      "analyzed_at",
      "integrity_status",
      "issues"
    ],
    "title": "GroupAnalysis"
  },
  "ExpectedVersions": {
    "properties": {
      "dealer": {
        "type": "integer",
        "maximum": 2147483647,
        "minimum": 1,
        "title": "Dealer"
      },
      "support": {
        "type": "integer",
        "maximum": 2147483647,
        "minimum": 1,
        "title": "Support"
      }
    },
    "additionalProperties": false,
    "type": "object",
    "required": [
      "dealer",
      "support"
    ],
    "title": "ExpectedVersions"
  },
  "AnalysisResult": {
    "properties": {
      "character_id": {
        "type": "string",
        "format": "uuid",
        "title": "Character Id"
      },
      "game_account_id": {
        "type": "string",
        "format": "uuid",
        "title": "Game Account Id"
      },
      "ownership_revision": {
        "type": "integer",
        "maximum": 2147483647,
        "minimum": 1,
        "title": "Ownership Revision"
      },
      "lifecycle_revision": {
        "type": "integer",
        "maximum": 2147483647,
        "minimum": 1,
        "title": "Lifecycle Revision"
      },
      "role": {
        "type": "string",
        "enum": [
          "dealer",
          "support"
        ],
        "title": "Role"
      },
      "analysis": {
        "$ref": "#/components/schemas/RoleAnalysis"
      }
    },
    "additionalProperties": false,
    "type": "object",
    "required": [
      "character_id",
      "game_account_id",
      "ownership_revision",
      "lifecycle_revision",
      "role",
      "analysis"
    ],
    "title": "AnalysisResult"
  },
  "AnalysisError": {
    "properties": {
      "code": {
        "type": "string",
        "title": "Code"
      },
      "message": {
        "type": "string",
        "title": "Message"
      },
      "request_id": {
        "type": "string",
        "title": "Request Id"
      },
      "retry_after_seconds": {
        "anyOf": [
          {
            "type": "integer",
            "minimum": 1
          },
          {
            "type": "null"
          }
        ],
        "title": "Retry After Seconds"
      },
      "retry_at": {
        "anyOf": [
          {
            "type": "string",
            "format": "date-time"
          },
          {
            "type": "null"
          }
        ],
        "title": "Retry At"
      }
    },
    "additionalProperties": false,
    "type": "object",
    "required": [
      "code",
      "message",
      "request_id",
      "retry_after_seconds",
      "retry_at"
    ],
    "title": "AnalysisError"
  },
  "Severity": {
    "type": "string",
    "enum": [
      "warning",
      "error"
    ],
    "title": "Severity"
  }
}
''';
