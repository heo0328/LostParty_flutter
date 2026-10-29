// Validation projection: Backend 22b16207; invite display c38144528c42eda7fcf2912fa412d3a005fc68e7.
const groupWireSchemaJson = r'''
{
  "operations": [
    {
      "method": "GET",
      "path": "/v1/me/usage-limits",
      "query": [],
      "request": {
        "type": "null"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/UsageLimits"
        }
      }
    },
    {
      "method": "POST",
      "path": "/v1/groups",
      "query": [],
      "request": {
        "$ref": "#/components/schemas/GroupCreateIn"
      },
      "responses": {
        "201": {
          "$ref": "#/components/schemas/GroupDetail"
        }
      }
    },
    {
      "method": "GET",
      "path": "/v1/groups",
      "query": [
        {
          "name": "q",
          "in": "query",
          "required": false,
          "schema": {
            "type": "string",
            "maxLength": 64,
            "default": "",
            "title": "Q"
          }
        },
        {
          "name": "limit",
          "in": "query",
          "required": false,
          "schema": {
            "type": "integer",
            "maximum": 50,
            "minimum": 1,
            "default": 20,
            "title": "Limit"
          }
        },
        {
          "name": "cursor",
          "in": "query",
          "required": false,
          "schema": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 2048
              },
              {
                "type": "null"
              }
            ],
            "title": "Cursor"
          }
        }
      ],
      "request": {
        "type": "null"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/GroupSummaryPage"
        }
      }
    },
    {
      "method": "GET",
      "path": "/v1/groups/{group_id}",
      "query": [],
      "request": {
        "type": "null"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/GroupSummary"
        }
      }
    },
    {
      "method": "PATCH",
      "path": "/v1/groups/{group_id}",
      "query": [],
      "request": {
        "$ref": "#/components/schemas/GroupRenameIn"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/GroupDetail"
        }
      }
    },
    {
      "method": "GET",
      "path": "/v1/me/groups",
      "query": [
        {
          "name": "limit",
          "in": "query",
          "required": false,
          "schema": {
            "type": "integer",
            "maximum": 50,
            "minimum": 1,
            "default": 20,
            "title": "Limit"
          }
        },
        {
          "name": "cursor",
          "in": "query",
          "required": false,
          "schema": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 2048
              },
              {
                "type": "null"
              }
            ],
            "title": "Cursor"
          }
        },
        {
          "name": "reader_profile",
          "in": "query",
          "required": false,
          "schema": {
            "anyOf": [
              {
                "const": "group-display-1",
                "type": "string"
              },
              {
                "type": "null"
              }
            ],
            "title": "Reader Profile"
          }
        }
      ],
      "request": {
        "type": "null"
      },
      "responses": {
        "200": {
          "anyOf": [
            {
              "$ref": "#/components/schemas/DisplayMyGroupPage"
            },
            {
              "$ref": "#/components/schemas/MyGroupPage"
            }
          ],
          "title": "Response My List V1 Me Groups Get"
        }
      }
    },
    {
      "method": "GET",
      "path": "/v1/me/groups/{group_id}",
      "query": [
        {
          "name": "reader_profile",
          "in": "query",
          "required": false,
          "schema": {
            "anyOf": [
              {
                "const": "group-display-1",
                "type": "string"
              },
              {
                "type": "null"
              }
            ],
            "title": "Reader Profile"
          }
        }
      ],
      "request": {
        "type": "null"
      },
      "responses": {
        "200": {
          "anyOf": [
            {
              "$ref": "#/components/schemas/DisplayDetail"
            },
            {
              "$ref": "#/components/schemas/GroupDetail"
            }
          ],
          "title": "Response Private Detail V1 Me Groups  Group Id  Get"
        }
      }
    },
    {
      "method": "GET",
      "path": "/v1/groups/{group_id}/members",
      "query": [
        {
          "name": "limit",
          "in": "query",
          "required": false,
          "schema": {
            "type": "integer",
            "maximum": 50,
            "minimum": 1,
            "default": 20,
            "title": "Limit"
          }
        },
        {
          "name": "cursor",
          "in": "query",
          "required": false,
          "schema": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 2048
              },
              {
                "type": "null"
              }
            ],
            "title": "Cursor"
          }
        },
        {
          "name": "reader_profile",
          "in": "query",
          "required": false,
          "schema": {
            "anyOf": [
              {
                "const": "group-display-1",
                "type": "string"
              },
              {
                "type": "null"
              }
            ],
            "title": "Reader Profile"
          }
        }
      ],
      "request": {
        "type": "null"
      },
      "responses": {
        "200": {
          "anyOf": [
            {
              "$ref": "#/components/schemas/DisplayMemberPage"
            },
            {
              "$ref": "#/components/schemas/GroupMemberPage"
            }
          ],
          "title": "Response Members V1 Groups  Group Id  Members Get"
        }
      }
    },
    {
      "method": "GET",
      "path": "/v1/groups/{group_id}/management",
      "query": [
        {
          "name": "management_profile",
          "in": "query",
          "required": false,
          "schema": {
            "anyOf": [
              {
                "const": "group-management-1",
                "type": "string"
              },
              {
                "type": "null"
              }
            ],
            "title": "Management Profile"
          }
        }
      ],
      "request": {
        "type": "null"
      },
      "responses": {
        "200": {
          "anyOf": [
            {
              "$ref": "#/components/schemas/ExtendedGroupManagement"
            },
            {
              "$ref": "#/components/schemas/GroupManagement"
            }
          ],
          "title": "Response Group Management V1 Groups  Group Id  Management Get"
        }
      }
    },
    {
      "method": "POST",
      "path": "/v1/groups/{group_id}/leadership-transfer",
      "query": [],
      "request": {
        "$ref": "#/components/schemas/TransferLeadershipIn"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/LeadershipTransferAck"
        }
      }
    },
    {
      "method": "POST",
      "path": "/v1/groups/{group_id}/leave",
      "query": [],
      "request": {
        "$ref": "#/components/schemas/LeaveGroupIn"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/GroupLeaveAck"
        }
      }
    },
    {
      "method": "GET",
      "path": "/v1/groups/{group_id}/invite-candidates",
      "query": [
        {
          "name": "character_name",
          "in": "query",
          "required": true,
          "schema": {
            "type": "string",
            "minLength": 1,
            "maxLength": 64,
            "title": "Character Name"
          }
        },
        {
          "name": "reader_profile",
          "in": "query",
          "required": false,
          "schema": {
            "anyOf": [
              {
                "const": "group-display-1",
                "type": "string"
              },
              {
                "type": "null"
              }
            ],
            "title": "Reader Profile"
          }
        }
      ],
      "request": {
        "type": "null"
      },
      "responses": {
        "200": {
          "anyOf": [
            {
              "$ref": "#/components/schemas/DisplayInviteCandidates"
            },
            {
              "$ref": "#/components/schemas/InviteCandidates"
            }
          ],
          "title": "Response Candidates V1 Groups  Group Id  Invite Candidates Get"
        }
      }
    },
    {
      "method": "POST",
      "path": "/v1/groups/{group_id}/invitations",
      "query": [],
      "request": {
        "$ref": "#/components/schemas/InviteIn"
      },
      "responses": {
        "201": {
          "$ref": "#/components/schemas/GroupRelation"
        }
      }
    },
    {
      "method": "POST",
      "path": "/v1/groups/{group_id}/applications",
      "query": [],
      "request": {
        "$ref": "#/components/schemas/ApplyIn"
      },
      "responses": {
        "201": {
          "$ref": "#/components/schemas/GroupRelation"
        }
      }
    },
    {
      "method": "GET",
      "path": "/v1/me/group-relations",
      "query": [
        {
          "name": "view",
          "in": "query",
          "required": false,
          "schema": {
            "enum": [
              "received_invitations",
              "sent_applications",
              "sent_invitations"
            ],
            "type": "string",
            "default": "received_invitations",
            "title": "View"
          }
        },
        {
          "name": "state",
          "in": "query",
          "required": false,
          "schema": {
            "enum": [
              "pending",
              "all"
            ],
            "type": "string",
            "default": "pending",
            "title": "State"
          }
        },
        {
          "name": "limit",
          "in": "query",
          "required": false,
          "schema": {
            "type": "integer",
            "maximum": 50,
            "minimum": 1,
            "default": 20,
            "title": "Limit"
          }
        },
        {
          "name": "cursor",
          "in": "query",
          "required": false,
          "schema": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 2048
              },
              {
                "type": "null"
              }
            ],
            "title": "Cursor"
          }
        }
      ],
      "request": {
        "type": "null"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/RelationPage"
        }
      }
    },
    {
      "method": "GET",
      "path": "/v1/groups/{group_id}/join-relations",
      "query": [
        {
          "name": "state",
          "in": "query",
          "required": false,
          "schema": {
            "enum": [
              "pending",
              "all"
            ],
            "type": "string",
            "default": "pending",
            "title": "State"
          }
        },
        {
          "name": "limit",
          "in": "query",
          "required": false,
          "schema": {
            "type": "integer",
            "maximum": 50,
            "minimum": 1,
            "default": 20,
            "title": "Limit"
          }
        },
        {
          "name": "cursor",
          "in": "query",
          "required": false,
          "schema": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 2048
              },
              {
                "type": "null"
              }
            ],
            "title": "Cursor"
          }
        }
      ],
      "request": {
        "type": "null"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/RelationPage"
        }
      }
    },
    {
      "method": "GET",
      "path": "/v1/group-relations/{relation_id}",
      "query": [],
      "request": {
        "type": "null"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/GroupRelation"
        }
      }
    },
    {
      "method": "POST",
      "path": "/v1/group-relations/{relation_id}/accept",
      "query": [],
      "request": {
        "$ref": "#/components/schemas/AcceptIn"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/GroupDetail"
        }
      }
    },
    {
      "method": "POST",
      "path": "/v1/group-relations/{relation_id}/approve",
      "query": [],
      "request": {
        "$ref": "#/components/schemas/RelationAction"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/GroupRelation"
        }
      }
    },
    {
      "method": "POST",
      "path": "/v1/group-relations/{relation_id}/reject",
      "query": [],
      "request": {
        "$ref": "#/components/schemas/RejectIn"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/GroupRelation"
        }
      }
    },
    {
      "method": "POST",
      "path": "/v1/group-relations/{relation_id}/cancel",
      "query": [],
      "request": {
        "$ref": "#/components/schemas/RelationAction"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/GroupRelation"
        }
      }
    },
    {
      "method": "GET",
      "path": "/v1/groups/{group_id}/blocked-subjects",
      "query": [
        {
          "name": "limit",
          "in": "query",
          "required": false,
          "schema": {
            "type": "integer",
            "maximum": 50,
            "minimum": 1,
            "default": 20,
            "title": "Limit"
          }
        },
        {
          "name": "cursor",
          "in": "query",
          "required": false,
          "schema": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 2048
              },
              {
                "type": "null"
              }
            ],
            "title": "Cursor"
          }
        },
        {
          "name": "reader_profile",
          "in": "query",
          "required": false,
          "schema": {
            "anyOf": [
              {
                "const": "group-display-1",
                "type": "string"
              },
              {
                "type": "null"
              }
            ],
            "title": "Reader Profile"
          }
        }
      ],
      "request": {
        "type": "null"
      },
      "responses": {
        "200": {
          "anyOf": [
            {
              "$ref": "#/components/schemas/DisplayBlockPage"
            },
            {
              "$ref": "#/components/schemas/BlockPage"
            }
          ],
          "title": "Response Blocked V1 Groups  Group Id  Blocked Subjects Get"
        }
      }
    },
    {
      "method": "POST",
      "path": "/v1/groups/{group_id}/join-subjects/{subject_id}/block",
      "query": [],
      "request": {
        "$ref": "#/components/schemas/BlockIn"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/JoinSubject"
        }
      }
    },
    {
      "method": "POST",
      "path": "/v1/groups/{group_id}/join-subjects/{subject_id}/unblock",
      "query": [],
      "request": {
        "$ref": "#/components/schemas/BlockIn"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/JoinSubject"
        }
      }
    },
    {
      "method": "GET",
      "path": "/v1/groups/{group_id}/join-code",
      "query": [],
      "request": {
        "type": "null"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/JoinCode"
        }
      }
    },
    {
      "method": "POST",
      "path": "/v1/groups/{group_id}/join-code",
      "query": [],
      "request": {
        "$ref": "#/components/schemas/CreateCodeIn"
      },
      "responses": {
        "201": {
          "$ref": "#/components/schemas/JoinCode"
        }
      }
    },
    {
      "method": "POST",
      "path": "/v1/groups/{group_id}/join-code/regenerate",
      "query": [],
      "request": {
        "$ref": "#/components/schemas/CodeCommand"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/JoinCode"
        }
      }
    },
    {
      "method": "POST",
      "path": "/v1/groups/{group_id}/join-code/revoke",
      "query": [],
      "request": {
        "$ref": "#/components/schemas/CodeCommand"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/JoinCode"
        }
      }
    },
    {
      "method": "PUT",
      "path": "/v1/groups/{group_id}/join-code/visibility",
      "query": [],
      "request": {
        "$ref": "#/components/schemas/CodeVisibilityIn"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/JoinCode"
        }
      }
    },
    {
      "method": "POST",
      "path": "/v1/group-join-codes/preview",
      "query": [],
      "request": {
        "$ref": "#/components/schemas/CodeInput"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/CodePreview"
        }
      }
    },
    {
      "method": "POST",
      "path": "/v1/group-join-codes/join",
      "query": [],
      "request": {
        "$ref": "#/components/schemas/CodeJoinIn"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/GroupDetail"
        }
      }
    },
    {
      "method": "GET",
      "path": "/v1/groups/{group_id}/members/{membership_id}/activity-characters",
      "query": [
        {
          "name": "limit",
          "in": "query",
          "required": false,
          "schema": {
            "type": "integer",
            "maximum": 50,
            "minimum": 1,
            "default": 20,
            "title": "Limit"
          }
        },
        {
          "name": "cursor",
          "in": "query",
          "required": false,
          "schema": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 2048
              },
              {
                "type": "null"
              }
            ],
            "title": "Cursor"
          }
        }
      ],
      "request": {
        "type": "null"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/ActivityCharacterPage"
        }
      }
    },
    {
      "method": "GET",
      "path": "/v1/me/group-request-counts",
      "query": [],
      "request": {
        "type": "null"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/GroupRequestCounts"
        }
      }
    },
    {
      "method": "GET",
      "path": "/v1/groups/{group_id}/join-request-counts",
      "query": [],
      "request": {
        "type": "null"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/GroupJoinRequestCounts"
        }
      }
    },
    {
      "method": "POST",
      "path": "/v1/groups/{group_id}/disband",
      "query": [],
      "request": {
        "$ref": "#/components/schemas/DisbandGroupIn"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/GroupDisbandAck"
        }
      }
    },
    {
      "method": "POST",
      "path": "/v1/groups/{group_id}/members/{membership_id}/remove",
      "query": [],
      "request": {
        "$ref": "#/components/schemas/RemoveGroupMemberIn"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/GroupRemoveAck"
        }
      }
    },
    {
      "method": "PUT",
      "path": "/v1/groups/{group_id}/representative",
      "query": [],
      "request": {
        "$ref": "#/components/schemas/ChangeGroupRepresentativeIn"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/GroupRepresentativeAck"
        }
      }
    },
    {
      "method": "GET",
      "path": "/v1/groups/{group_id}/raid-rooms",
      "query": [
        {
          "name": "limit",
          "in": "query",
          "required": false,
          "schema": {
            "type": "integer",
            "maximum": 50,
            "minimum": 1,
            "default": 20,
            "title": "Limit"
          }
        },
        {
          "name": "cursor",
          "in": "query",
          "required": false,
          "schema": {
            "anyOf": [
              {
                "type": "string",
                "minLength": 1,
                "maxLength": 2048
              },
              {
                "type": "null"
              }
            ],
            "title": "Cursor"
          }
        }
      ],
      "request": {
        "type": "null"
      },
      "responses": {
        "200": {
          "$ref": "#/components/schemas/GroupRaidRoomPage"
        }
      }
    }
  ],
  "schemas": {
    "AcceptIn": {
      "properties": {
        "expected_relation_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Relation Revision"
        },
        "expected_group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Group Revision"
        },
        "expected_members_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Members Revision"
        },
        "registration_id": {
          "type": "string",
          "format": "uuid",
          "title": "Registration Id"
        },
        "character_id": {
          "type": "string",
          "format": "uuid",
          "title": "Character Id"
        },
        "expected_registration_version": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Registration Version"
        },
        "expected_ownership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Ownership Revision"
        },
        "expected_roster_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Roster Revision"
        },
        "expected_lifecycle_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Lifecycle Revision"
        },
        "expected_limits_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Limits Revision"
        },
        "expected_usage_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Usage Revision"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "expected_relation_revision",
        "expected_group_revision",
        "expected_members_revision",
        "registration_id",
        "character_id",
        "expected_registration_version",
        "expected_ownership_revision",
        "expected_roster_revision",
        "expected_lifecycle_revision",
        "expected_limits_revision",
        "expected_usage_revision"
      ],
      "title": "AcceptIn"
    },
    "AccountLimitIssue": {
      "properties": {
        "code": {
          "type": "string",
          "enum": [
            "MEMBER_GROUP_LIMIT_EXCEEDED",
            "MEMBER_RAID_LIMIT_EXCEEDED"
          ],
          "title": "Code"
        },
        "dimension": {
          "type": "string",
          "enum": [
            "joined_groups",
            "raid_rooms"
          ],
          "title": "Dimension"
        },
        "used": {
          "type": "integer",
          "minimum": 0.0,
          "title": "Used"
        },
        "limit": {
          "type": "integer",
          "minimum": 0.0,
          "title": "Limit"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "code",
        "dimension",
        "used",
        "limit"
      ],
      "title": "AccountLimitIssue"
    },
    "ActivityCharacter": {
      "properties": {
        "character_id": {
          "type": "string",
          "format": "uuid",
          "title": "Character Id"
        },
        "display": {
          "$ref": "#/components/schemas/CharacterDisplay"
        },
        "character_spec": {
          "$ref": "#/components/schemas/CharacterSpec"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "character_id",
        "display",
        "character_spec"
      ],
      "title": "ActivityCharacter"
    },
    "ActivityCharacterPage": {
      "properties": {
        "group_id": {
          "type": "string",
          "format": "uuid",
          "title": "Group Id"
        },
        "membership_id": {
          "type": "string",
          "format": "uuid",
          "title": "Membership Id"
        },
        "group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Group Revision"
        },
        "members_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Members Revision"
        },
        "evaluated_at": {
          "type": "string",
          "format": "date-time",
          "title": "Evaluated At"
        },
        "snapshot_revision": {
          "type": "string",
          "title": "Snapshot Revision"
        },
        "items": {
          "items": {
            "$ref": "#/components/schemas/ActivityCharacter"
          },
          "type": "array",
          "title": "Items"
        },
        "next_cursor": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ],
          "title": "Next Cursor"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "group_id",
        "membership_id",
        "group_revision",
        "members_revision",
        "evaluated_at",
        "snapshot_revision",
        "items",
        "next_cursor"
      ],
      "title": "ActivityCharacterPage"
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
    "ApplyIn": {
      "properties": {
        "registration_id": {
          "type": "string",
          "format": "uuid",
          "title": "Registration Id"
        },
        "character_id": {
          "type": "string",
          "format": "uuid",
          "title": "Character Id"
        },
        "expected_registration_version": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Registration Version"
        },
        "expected_ownership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Ownership Revision"
        },
        "expected_roster_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Roster Revision"
        },
        "expected_lifecycle_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Lifecycle Revision"
        },
        "expected_group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Group Revision"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "registration_id",
        "character_id",
        "expected_registration_version",
        "expected_ownership_revision",
        "expected_roster_revision",
        "expected_lifecycle_revision",
        "expected_group_revision"
      ],
      "title": "ApplyIn"
    },
    "BlockIn": {
      "properties": {
        "expected_subject_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Subject Revision"
        },
        "expected_group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Group Revision"
        },
        "expected_membership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Membership Revision"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "expected_subject_revision",
        "expected_group_revision",
        "expected_membership_revision"
      ],
      "title": "BlockIn"
    },
    "BlockPage": {
      "properties": {
        "items": {
          "items": {
            "$ref": "#/components/schemas/JoinSubject"
          },
          "type": "array",
          "title": "Items"
        },
        "next_cursor": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ],
          "title": "Next Cursor"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "items",
        "next_cursor"
      ],
      "title": "BlockPage"
    },
    "ChangeGroupRepresentativeIn": {
      "properties": {
        "registration_id": {
          "type": "string",
          "format": "uuid",
          "title": "Registration Id"
        },
        "character_id": {
          "type": "string",
          "format": "uuid",
          "title": "Character Id"
        },
        "expected_registration_version": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Registration Version"
        },
        "expected_ownership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Ownership Revision"
        },
        "expected_roster_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Roster Revision"
        },
        "expected_lifecycle_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Lifecycle Revision"
        },
        "expected_group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Group Revision"
        },
        "expected_members_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Members Revision"
        },
        "expected_membership_id": {
          "type": "string",
          "format": "uuid",
          "title": "Expected Membership Id"
        },
        "expected_membership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Membership Revision"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "registration_id",
        "character_id",
        "expected_registration_version",
        "expected_ownership_revision",
        "expected_roster_revision",
        "expected_lifecycle_revision",
        "expected_group_revision",
        "expected_members_revision",
        "expected_membership_id",
        "expected_membership_revision"
      ],
      "title": "ChangeGroupRepresentativeIn"
    },
    "CharacterDisplay": {
      "properties": {
        "server_name": {
          "type": "string",
          "title": "Server Name"
        },
        "character_name": {
          "type": "string",
          "title": "Character Name"
        },
        "class_name": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ],
          "title": "Class Name"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "server_name",
        "character_name",
        "class_name"
      ],
      "title": "CharacterDisplay"
    },
    "CharacterSpec": {
      "properties": {
        "character_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ],
          "title": "Character Id"
        },
        "state": {
          "type": "string",
          "enum": [
            "available",
            "partial",
            "unavailable"
          ],
          "title": "State"
        },
        "reason": {
          "anyOf": [
            {
              "type": "string",
              "enum": [
                "CHARACTER_REFERENCE_UNAVAILABLE",
                "CHARACTER_NOT_CURRENTLY_ELIGIBLE",
                "CHARACTER_DATA_UNAVAILABLE",
                "ROLE_ANALYSIS_UNAVAILABLE"
              ]
            },
            {
              "type": "null"
            }
          ],
          "title": "Reason"
        },
        "item_level": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ],
          "title": "Item Level"
        },
        "item_level_source": {
          "type": "string",
          "enum": [
            "stored_character_summary",
            "unavailable"
          ],
          "title": "Item Level Source"
        },
        "summary_fetched_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ],
          "title": "Summary Fetched At"
        },
        "dealer": {
          "$ref": "#/components/schemas/GroupRolePower"
        },
        "support": {
          "$ref": "#/components/schemas/GroupRolePower"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "character_id",
        "state",
        "reason",
        "item_level",
        "item_level_source",
        "summary_fetched_at",
        "dealer",
        "support"
      ],
      "title": "CharacterSpec"
    },
    "CodeCommand": {
      "properties": {
        "expected_group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Group Revision"
        },
        "expected_membership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Membership Revision"
        },
        "expected_code_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ],
          "title": "Expected Code Id"
        },
        "expected_code_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Code Revision"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "expected_group_revision",
        "expected_membership_revision",
        "expected_code_id",
        "expected_code_revision"
      ],
      "title": "CodeCommand"
    },
    "CodeInput": {
      "properties": {
        "code": {
          "type": "string",
          "maxLength": 64,
          "minLength": 1,
          "title": "Code"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "code"
      ],
      "title": "CodeInput"
    },
    "CodeJoinIn": {
      "properties": {
        "code": {
          "type": "string",
          "maxLength": 64,
          "minLength": 1,
          "title": "Code"
        },
        "registration_id": {
          "type": "string",
          "format": "uuid",
          "title": "Registration Id"
        },
        "character_id": {
          "type": "string",
          "format": "uuid",
          "title": "Character Id"
        },
        "expected_registration_version": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Registration Version"
        },
        "expected_ownership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Ownership Revision"
        },
        "expected_roster_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Roster Revision"
        },
        "expected_lifecycle_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Lifecycle Revision"
        },
        "expected_group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Group Revision"
        },
        "expected_members_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Members Revision"
        },
        "expected_code_id": {
          "type": "string",
          "format": "uuid",
          "title": "Expected Code Id"
        },
        "expected_code_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Code Revision"
        },
        "expected_limits_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Limits Revision"
        },
        "expected_usage_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Usage Revision"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "code",
        "registration_id",
        "character_id",
        "expected_registration_version",
        "expected_ownership_revision",
        "expected_roster_revision",
        "expected_lifecycle_revision",
        "expected_group_revision",
        "expected_members_revision",
        "expected_code_id",
        "expected_code_revision",
        "expected_limits_revision",
        "expected_usage_revision"
      ],
      "title": "CodeJoinIn"
    },
    "CodePreview": {
      "properties": {
        "group": {
          "$ref": "#/components/schemas/GroupSummary"
        },
        "members_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Members Revision"
        },
        "code_id": {
          "type": "string",
          "format": "uuid",
          "title": "Code Id"
        },
        "code_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Code Revision"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "group",
        "members_revision",
        "code_id",
        "code_revision"
      ],
      "title": "CodePreview"
    },
    "CodeVisibilityIn": {
      "properties": {
        "expected_group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Group Revision"
        },
        "expected_membership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Membership Revision"
        },
        "expected_code_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ],
          "title": "Expected Code Id"
        },
        "expected_code_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Code Revision"
        },
        "visible_to_members": {
          "type": "boolean",
          "title": "Visible To Members"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "expected_group_revision",
        "expected_membership_revision",
        "expected_code_id",
        "expected_code_revision",
        "visible_to_members"
      ],
      "title": "CodeVisibilityIn"
    },
    "CreateCodeIn": {
      "properties": {
        "expected_group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Group Revision"
        },
        "expected_membership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Membership Revision"
        },
        "expected_code_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ],
          "title": "Expected Code Id"
        },
        "expected_code_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Code Revision"
        },
        "visible_to_members": {
          "type": "boolean",
          "title": "Visible To Members",
          "default": false
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "expected_group_revision",
        "expected_membership_revision",
        "expected_code_id",
        "expected_code_revision"
      ],
      "title": "CreateCodeIn"
    },
    "DisbandGroupIn": {
      "properties": {
        "expected_group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Group Revision"
        },
        "expected_members_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Members Revision"
        },
        "expected_membership_id": {
          "type": "string",
          "format": "uuid",
          "title": "Expected Membership Id"
        },
        "expected_membership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Membership Revision"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "expected_group_revision",
        "expected_members_revision",
        "expected_membership_id",
        "expected_membership_revision"
      ],
      "title": "DisbandGroupIn"
    },
    "DisplayBlockPage": {
      "properties": {
        "profile": {
          "type": "string",
          "const": "group-display-1",
          "title": "Profile"
        },
        "evaluated_at": {
          "type": "string",
          "format": "date-time",
          "title": "Evaluated At"
        },
        "snapshot_revision": {
          "type": "string",
          "title": "Snapshot Revision"
        },
        "items": {
          "items": {
            "$ref": "#/components/schemas/DisplaySubject"
          },
          "type": "array",
          "title": "Items"
        },
        "next_cursor": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ],
          "title": "Next Cursor"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "profile",
        "evaluated_at",
        "snapshot_revision",
        "items",
        "next_cursor"
      ],
      "title": "DisplayBlockPage"
    },
    "DisplayDetail": {
      "properties": {
        "group": {
          "$ref": "#/components/schemas/GroupSummary"
        },
        "created_at": {
          "type": "string",
          "format": "date-time",
          "title": "Created At"
        },
        "leader_membership_id": {
          "type": "string",
          "format": "uuid",
          "title": "Leader Membership Id"
        },
        "members_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Members Revision"
        },
        "my_membership": {
          "$ref": "#/components/schemas/app__groups__schemas__MyMembership"
        },
        "permissions": {
          "$ref": "#/components/schemas/app__groups__schemas__Permissions"
        },
        "capacity": {
          "$ref": "#/components/schemas/GroupCapacity"
        },
        "profile": {
          "type": "string",
          "const": "group-display-1",
          "title": "Profile"
        },
        "evaluated_at": {
          "type": "string",
          "format": "date-time",
          "title": "Evaluated At"
        },
        "snapshot_revision": {
          "type": "string",
          "title": "Snapshot Revision"
        },
        "last_activity_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ],
          "title": "Last Activity At"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "group",
        "created_at",
        "leader_membership_id",
        "members_revision",
        "my_membership",
        "permissions",
        "capacity",
        "profile",
        "evaluated_at",
        "snapshot_revision",
        "last_activity_at"
      ],
      "title": "DisplayDetail"
    },
    "DisplayMember": {
      "properties": {
        "membership_id": {
          "type": "string",
          "format": "uuid",
          "title": "Membership Id"
        },
        "role": {
          "type": "string",
          "enum": [
            "leader",
            "member"
          ],
          "title": "Role"
        },
        "revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Revision"
        },
        "display": {
          "anyOf": [
            {
              "$ref": "#/components/schemas/CharacterDisplay"
            },
            {
              "type": "null"
            }
          ]
        },
        "joined_at": {
          "type": "string",
          "format": "date-time",
          "title": "Joined At"
        },
        "is_me": {
          "type": "boolean",
          "title": "Is Me"
        },
        "character_spec": {
          "$ref": "#/components/schemas/CharacterSpec"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "membership_id",
        "role",
        "revision",
        "display",
        "joined_at",
        "is_me",
        "character_spec"
      ],
      "title": "DisplayMember"
    },
    "DisplayMemberPage": {
      "properties": {
        "profile": {
          "type": "string",
          "const": "group-display-1",
          "title": "Profile"
        },
        "evaluated_at": {
          "type": "string",
          "format": "date-time",
          "title": "Evaluated At"
        },
        "snapshot_revision": {
          "type": "string",
          "title": "Snapshot Revision"
        },
        "group_id": {
          "type": "string",
          "format": "uuid",
          "title": "Group Id"
        },
        "group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Group Revision"
        },
        "members_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Members Revision"
        },
        "items": {
          "items": {
            "$ref": "#/components/schemas/DisplayMember"
          },
          "type": "array",
          "title": "Items"
        },
        "next_cursor": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ],
          "title": "Next Cursor"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "profile",
        "evaluated_at",
        "snapshot_revision",
        "group_id",
        "group_revision",
        "members_revision",
        "items",
        "next_cursor"
      ],
      "title": "DisplayMemberPage"
    },
    "DisplayMyGroupPage": {
      "properties": {
        "profile": {
          "type": "string",
          "const": "group-display-1",
          "title": "Profile"
        },
        "evaluated_at": {
          "type": "string",
          "format": "date-time",
          "title": "Evaluated At"
        },
        "snapshot_revision": {
          "type": "string",
          "title": "Snapshot Revision"
        },
        "directory_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Directory Revision"
        },
        "items": {
          "items": {
            "$ref": "#/components/schemas/DisplayDetail"
          },
          "type": "array",
          "title": "Items"
        },
        "next_cursor": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ],
          "title": "Next Cursor"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "profile",
        "evaluated_at",
        "snapshot_revision",
        "directory_revision",
        "items",
        "next_cursor"
      ],
      "title": "DisplayMyGroupPage"
    },
    "DisplaySubject": {
      "properties": {
        "subject_id": {
          "type": "string",
          "format": "uuid",
          "title": "Subject Id"
        },
        "revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Revision"
        },
        "display": {
          "anyOf": [
            {
              "$ref": "#/components/schemas/CharacterDisplay"
            },
            {
              "type": "null"
            }
          ]
        },
        "application_count": {
          "type": "integer",
          "minimum": 0.0,
          "title": "Application Count"
        },
        "blocked": {
          "type": "boolean",
          "title": "Blocked"
        },
        "blocked_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ],
          "title": "Blocked At"
        },
        "character_spec": {
          "$ref": "#/components/schemas/CharacterSpec"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "subject_id",
        "revision",
        "display",
        "application_count",
        "blocked",
        "blocked_at",
        "character_spec"
      ],
      "title": "DisplaySubject"
    },
    "ExtendedGroupManagement": {
      "properties": {
        "profile": {
          "type": "string",
          "const": "group-management-1",
          "title": "Profile"
        },
        "group_id": {
          "type": "string",
          "format": "uuid",
          "title": "Group Id"
        },
        "group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Group Revision"
        },
        "members_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Members Revision"
        },
        "my_membership": {
          "$ref": "#/components/schemas/app__groups__schemas__MyMembership"
        },
        "permissions": {
          "$ref": "#/components/schemas/ExtendedManagementPermissions"
        },
        "recruitment_state": {
          "type": "string",
          "enum": [
            "clear",
            "blocked",
            "unavailable"
          ],
          "title": "Recruitment State"
        },
        "blocking_room_count": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 0.0
            },
            {
              "type": "null"
            }
          ],
          "title": "Blocking Room Count"
        },
        "evidence_revision": {
          "type": "string",
          "title": "Evidence Revision"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "profile",
        "group_id",
        "group_revision",
        "members_revision",
        "my_membership",
        "permissions",
        "recruitment_state",
        "blocking_room_count",
        "evidence_revision"
      ],
      "title": "ExtendedGroupManagement"
    },
    "ExtendedManagementPermissions": {
      "properties": {
        "transfer_leadership": {
          "$ref": "#/components/schemas/app__groups__schemas__Permission"
        },
        "leave": {
          "$ref": "#/components/schemas/app__groups__schemas__Permission"
        },
        "disband": {
          "$ref": "#/components/schemas/app__groups__schemas__Permission"
        },
        "remove_member": {
          "$ref": "#/components/schemas/app__groups__schemas__Permission"
        },
        "change_representative": {
          "$ref": "#/components/schemas/app__groups__schemas__Permission"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "transfer_leadership",
        "leave",
        "disband",
        "remove_member",
        "change_representative"
      ],
      "title": "ExtendedManagementPermissions"
    },
    "GroupAnalysis": {
      "properties": {
        "version": {
          "type": "integer",
          "minimum": 1.0,
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
    "GroupCapacity": {
      "properties": {
        "limit": {
          "type": "integer",
          "minimum": 0.0,
          "title": "Limit"
        },
        "used": {
          "type": "integer",
          "minimum": 0.0,
          "title": "Used"
        },
        "remaining": {
          "type": "integer",
          "minimum": 0.0,
          "title": "Remaining"
        },
        "state": {
          "type": "string",
          "enum": [
            "within",
            "at_limit",
            "exceeded"
          ],
          "title": "State"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "limit",
        "used",
        "remaining",
        "state"
      ],
      "title": "GroupCapacity"
    },
    "GroupCreateIn": {
      "properties": {
        "registration_id": {
          "type": "string",
          "format": "uuid",
          "title": "Registration Id"
        },
        "character_id": {
          "type": "string",
          "format": "uuid",
          "title": "Character Id"
        },
        "expected_registration_version": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Registration Version"
        },
        "expected_ownership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Ownership Revision"
        },
        "expected_roster_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Roster Revision"
        },
        "expected_lifecycle_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Lifecycle Revision"
        },
        "name": {
          "type": "string",
          "title": "Name",
          "description": "Omitted selects the automatic name; explicit null is rejected."
        },
        "expected_limits_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Limits Revision"
        },
        "expected_usage_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Usage Revision"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "registration_id",
        "character_id",
        "expected_registration_version",
        "expected_ownership_revision",
        "expected_roster_revision",
        "expected_lifecycle_revision",
        "expected_limits_revision",
        "expected_usage_revision"
      ],
      "title": "GroupCreateIn"
    },
    "GroupDetail": {
      "properties": {
        "group": {
          "$ref": "#/components/schemas/GroupSummary"
        },
        "created_at": {
          "type": "string",
          "format": "date-time",
          "title": "Created At"
        },
        "leader_membership_id": {
          "type": "string",
          "format": "uuid",
          "title": "Leader Membership Id"
        },
        "members_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Members Revision"
        },
        "my_membership": {
          "$ref": "#/components/schemas/app__groups__schemas__MyMembership"
        },
        "permissions": {
          "$ref": "#/components/schemas/app__groups__schemas__Permissions"
        },
        "capacity": {
          "$ref": "#/components/schemas/GroupCapacity"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "group",
        "created_at",
        "leader_membership_id",
        "members_revision",
        "my_membership",
        "permissions",
        "capacity"
      ],
      "title": "GroupDetail"
    },
    "GroupDisbandAck": {
      "properties": {
        "group_id": {
          "type": "string",
          "format": "uuid",
          "title": "Group Id"
        },
        "membership_id": {
          "type": "string",
          "format": "uuid",
          "title": "Membership Id"
        },
        "membership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Membership Revision"
        },
        "group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Group Revision"
        },
        "members_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Members Revision"
        },
        "ended_at": {
          "type": "string",
          "format": "date-time",
          "title": "Ended At"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "group_id",
        "membership_id",
        "membership_revision",
        "group_revision",
        "members_revision",
        "ended_at"
      ],
      "title": "GroupDisbandAck"
    },
    "GroupJoinRequestCounts": {
      "properties": {
        "group_id": {
          "type": "string",
          "format": "uuid",
          "title": "Group Id"
        },
        "group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Group Revision"
        },
        "members_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Members Revision"
        },
        "evaluated_at": {
          "type": "string",
          "format": "date-time",
          "title": "Evaluated At"
        },
        "counts_revision": {
          "type": "string",
          "title": "Counts Revision"
        },
        "valid_until": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ],
          "title": "Valid Until"
        },
        "pending_applications": {
          "type": "integer",
          "minimum": 0.0,
          "title": "Pending Applications"
        },
        "pending_invitations": {
          "type": "integer",
          "minimum": 0.0,
          "title": "Pending Invitations"
        },
        "action_required": {
          "type": "integer",
          "minimum": 0.0,
          "title": "Action Required"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "group_id",
        "group_revision",
        "members_revision",
        "evaluated_at",
        "counts_revision",
        "valid_until",
        "pending_applications",
        "pending_invitations",
        "action_required"
      ],
      "title": "GroupJoinRequestCounts"
    },
    "GroupLeaveAck": {
      "properties": {
        "group_id": {
          "type": "string",
          "format": "uuid",
          "title": "Group Id"
        },
        "membership_id": {
          "type": "string",
          "format": "uuid",
          "title": "Membership Id"
        },
        "membership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Membership Revision"
        },
        "ended_at": {
          "type": "string",
          "format": "date-time",
          "title": "Ended At"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "group_id",
        "membership_id",
        "membership_revision",
        "ended_at"
      ],
      "title": "GroupLeaveAck"
    },
    "GroupManagement": {
      "properties": {
        "group_id": {
          "type": "string",
          "format": "uuid",
          "title": "Group Id"
        },
        "group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Group Revision"
        },
        "members_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Members Revision"
        },
        "my_membership": {
          "$ref": "#/components/schemas/app__groups__schemas__MyMembership"
        },
        "permissions": {
          "$ref": "#/components/schemas/ManagementPermissions"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "group_id",
        "group_revision",
        "members_revision",
        "my_membership",
        "permissions"
      ],
      "title": "GroupManagement"
    },
    "GroupMember": {
      "properties": {
        "membership_id": {
          "type": "string",
          "format": "uuid",
          "title": "Membership Id"
        },
        "role": {
          "type": "string",
          "enum": [
            "leader",
            "member"
          ],
          "title": "Role"
        },
        "revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Revision"
        },
        "display": {
          "anyOf": [
            {
              "$ref": "#/components/schemas/CharacterDisplay"
            },
            {
              "type": "null"
            }
          ]
        },
        "joined_at": {
          "type": "string",
          "format": "date-time",
          "title": "Joined At"
        },
        "is_me": {
          "type": "boolean",
          "title": "Is Me"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "membership_id",
        "role",
        "revision",
        "display",
        "joined_at",
        "is_me"
      ],
      "title": "GroupMember"
    },
    "GroupMemberPage": {
      "properties": {
        "group_id": {
          "type": "string",
          "format": "uuid",
          "title": "Group Id"
        },
        "group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Group Revision"
        },
        "members_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Members Revision"
        },
        "items": {
          "items": {
            "$ref": "#/components/schemas/GroupMember"
          },
          "type": "array",
          "title": "Items"
        },
        "next_cursor": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ],
          "title": "Next Cursor"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "group_id",
        "group_revision",
        "members_revision",
        "items",
        "next_cursor"
      ],
      "title": "GroupMemberPage"
    },
    "GroupRaidRoom": {
      "properties": {
        "room_id": {
          "type": "string",
          "format": "uuid",
          "title": "Room Id"
        },
        "title": {
          "type": "string",
          "title": "Title"
        },
        "scope": {
          "type": "string",
          "const": "group",
          "title": "Scope"
        },
        "group_id": {
          "type": "string",
          "format": "uuid",
          "title": "Group Id"
        },
        "room_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Room Revision"
        },
        "state": {
          "type": "string",
          "enum": [
            "active",
            "review_required"
          ],
          "title": "State"
        },
        "reason": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ],
          "title": "Reason"
        },
        "targets": {
          "items": {
            "$ref": "#/components/schemas/GroupRaidTarget"
          },
          "type": "array",
          "title": "Targets"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "room_id",
        "title",
        "scope",
        "group_id",
        "room_revision",
        "state",
        "reason",
        "targets"
      ],
      "title": "GroupRaidRoom"
    },
    "GroupRaidRoomPage": {
      "properties": {
        "group_id": {
          "type": "string",
          "format": "uuid",
          "title": "Group Id"
        },
        "group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Group Revision"
        },
        "members_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Members Revision"
        },
        "evaluated_at": {
          "type": "string",
          "format": "date-time",
          "title": "Evaluated At"
        },
        "evidence_revision": {
          "type": "string",
          "title": "Evidence Revision"
        },
        "state": {
          "type": "string",
          "enum": [
            "clear",
            "blocked",
            "unavailable"
          ],
          "title": "State"
        },
        "blocking_room_count": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 0.0
            },
            {
              "type": "null"
            }
          ],
          "title": "Blocking Room Count"
        },
        "items": {
          "items": {
            "$ref": "#/components/schemas/GroupRaidRoom"
          },
          "type": "array",
          "title": "Items"
        },
        "next_cursor": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ],
          "title": "Next Cursor"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "group_id",
        "group_revision",
        "members_revision",
        "evaluated_at",
        "evidence_revision",
        "state",
        "blocking_room_count",
        "items",
        "next_cursor"
      ],
      "title": "GroupRaidRoomPage"
    },
    "GroupRaidTarget": {
      "properties": {
        "room_cycle_id": {
          "type": "string",
          "format": "uuid",
          "title": "Room Cycle Id"
        },
        "target_cycle_key": {
          "type": "string",
          "format": "date",
          "title": "Target Cycle Key"
        },
        "generation": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1.0
            },
            {
              "type": "null"
            }
          ],
          "title": "Generation"
        },
        "target_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Target Revision"
        },
        "state": {
          "type": "string",
          "title": "State"
        },
        "leader_display": {
          "anyOf": [
            {
              "$ref": "#/components/schemas/CharacterDisplay"
            },
            {
              "type": "null"
            }
          ]
        },
        "detail_available": {
          "type": "boolean",
          "title": "Detail Available"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "room_cycle_id",
        "target_cycle_key",
        "generation",
        "target_revision",
        "state",
        "leader_display",
        "detail_available"
      ],
      "title": "GroupRaidTarget"
    },
    "GroupRelation": {
      "properties": {
        "relation_id": {
          "type": "string",
          "format": "uuid",
          "title": "Relation Id"
        },
        "subject_id": {
          "type": "string",
          "format": "uuid",
          "title": "Subject Id"
        },
        "kind": {
          "type": "string",
          "enum": [
            "invitation",
            "application"
          ],
          "title": "Kind"
        },
        "state": {
          "type": "string",
          "enum": [
            "pending",
            "accepted",
            "rejected",
            "cancelled",
            "expired",
            "blocked",
            "joined_by_code"
          ],
          "title": "State"
        },
        "revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Revision"
        },
        "group": {
          "$ref": "#/components/schemas/GroupSummary"
        },
        "members_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Members Revision"
        },
        "display": {
          "anyOf": [
            {
              "$ref": "#/components/schemas/CharacterDisplay"
            },
            {
              "type": "null"
            }
          ]
        },
        "created_at": {
          "type": "string",
          "format": "date-time",
          "title": "Created At"
        },
        "expires_at": {
          "type": "string",
          "format": "date-time",
          "title": "Expires At"
        },
        "ended_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ],
          "title": "Ended At"
        },
        "application_count": {
          "type": "integer",
          "minimum": 0.0,
          "title": "Application Count"
        },
        "permissions": {
          "$ref": "#/components/schemas/RelationPermissions"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "relation_id",
        "subject_id",
        "kind",
        "state",
        "revision",
        "group",
        "members_revision",
        "display",
        "created_at",
        "expires_at",
        "ended_at",
        "application_count",
        "permissions"
      ],
      "title": "GroupRelation"
    },
    "GroupRemoveAck": {
      "properties": {
        "group_id": {
          "type": "string",
          "format": "uuid",
          "title": "Group Id"
        },
        "membership_id": {
          "type": "string",
          "format": "uuid",
          "title": "Membership Id"
        },
        "membership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Membership Revision"
        },
        "group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Group Revision"
        },
        "members_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Members Revision"
        },
        "ended_at": {
          "type": "string",
          "format": "date-time",
          "title": "Ended At"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "group_id",
        "membership_id",
        "membership_revision",
        "group_revision",
        "members_revision",
        "ended_at"
      ],
      "title": "GroupRemoveAck"
    },
    "GroupRenameIn": {
      "properties": {
        "name": {
          "type": "string",
          "title": "Name"
        },
        "expected_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Revision"
        },
        "expected_membership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Membership Revision"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "name",
        "expected_revision",
        "expected_membership_revision"
      ],
      "title": "GroupRenameIn"
    },
    "GroupRepresentative": {
      "properties": {
        "display": {
          "$ref": "#/components/schemas/CharacterDisplay"
        },
        "status": {
          "type": "string",
          "enum": [
            "valid",
            "needs_update"
          ],
          "title": "Status"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "display",
        "status"
      ],
      "title": "GroupRepresentative"
    },
    "GroupRepresentativeAck": {
      "properties": {
        "group_id": {
          "type": "string",
          "format": "uuid",
          "title": "Group Id"
        },
        "group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Group Revision"
        },
        "character_id": {
          "type": "string",
          "format": "uuid",
          "title": "Character Id"
        },
        "representative": {
          "$ref": "#/components/schemas/GroupRepresentative"
        },
        "changed_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ],
          "title": "Changed At"
        },
        "outcome": {
          "type": "string",
          "enum": [
            "applied",
            "noop"
          ],
          "title": "Outcome"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "group_id",
        "group_revision",
        "character_id",
        "representative",
        "changed_at",
        "outcome"
      ],
      "title": "GroupRepresentativeAck"
    },
    "GroupRequestCounts": {
      "properties": {
        "evaluated_at": {
          "type": "string",
          "format": "date-time",
          "title": "Evaluated At"
        },
        "counts_revision": {
          "type": "string",
          "title": "Counts Revision"
        },
        "valid_until": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ],
          "title": "Valid Until"
        },
        "received_invitations": {
          "type": "integer",
          "minimum": 0.0,
          "title": "Received Invitations"
        },
        "sent_applications": {
          "type": "integer",
          "minimum": 0.0,
          "title": "Sent Applications"
        },
        "managed_applications": {
          "type": "integer",
          "minimum": 0.0,
          "title": "Managed Applications"
        },
        "managed_invitations": {
          "type": "integer",
          "minimum": 0.0,
          "title": "Managed Invitations"
        },
        "action_required": {
          "type": "integer",
          "minimum": 0.0,
          "title": "Action Required"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "evaluated_at",
        "counts_revision",
        "valid_until",
        "received_invitations",
        "sent_applications",
        "managed_applications",
        "managed_invitations",
        "action_required"
      ],
      "title": "GroupRequestCounts"
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
            "stored_role_success",
            "unavailable"
          ],
          "title": "Source"
        },
        "trust": {
          "anyOf": [
            {
              "type": "string",
              "const": "client_submitted"
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
        "power_revision": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 1.0
            },
            {
              "type": "null"
            }
          ],
          "title": "Power Revision"
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
        "power_revision",
        "analysis",
        "reason"
      ],
      "title": "GroupRolePower"
    },
    "GroupSummary": {
      "properties": {
        "group_id": {
          "type": "string",
          "format": "uuid",
          "title": "Group Id"
        },
        "name": {
          "type": "string",
          "title": "Name"
        },
        "revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Revision"
        },
        "member_count": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Member Count"
        },
        "representative": {
          "$ref": "#/components/schemas/GroupRepresentative"
        },
        "leader_display": {
          "anyOf": [
            {
              "$ref": "#/components/schemas/CharacterDisplay"
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
        "group_id",
        "name",
        "revision",
        "member_count",
        "representative",
        "leader_display"
      ],
      "title": "GroupSummary"
    },
    "GroupSummaryPage": {
      "properties": {
        "items": {
          "items": {
            "$ref": "#/components/schemas/GroupSummary"
          },
          "type": "array",
          "title": "Items"
        },
        "directory_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Directory Revision"
        },
        "next_cursor": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ],
          "title": "Next Cursor"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "items",
        "directory_revision",
        "next_cursor"
      ],
      "title": "GroupSummaryPage"
    },
    "InviteCandidate": {
      "properties": {
        "target_character_id": {
          "type": "string",
          "format": "uuid",
          "title": "Target Character Id"
        },
        "display": {
          "$ref": "#/components/schemas/CharacterDisplay"
        },
        "ownership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Ownership Revision"
        },
        "lifecycle_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Lifecycle Revision"
        },
        "item_level": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ],
          "title": "Item Level"
        },
        "combat_power": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ],
          "title": "Combat Power"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "target_character_id",
        "display",
        "ownership_revision",
        "lifecycle_revision",
        "item_level",
        "combat_power"
      ],
      "title": "InviteCandidate"
    },
    "InviteCandidates": {
      "properties": {
        "items": {
          "items": {
            "$ref": "#/components/schemas/InviteCandidate"
          },
          "type": "array",
          "title": "Items"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "items"
      ],
      "title": "InviteCandidates"
    },
    "InviteIn": {
      "properties": {
        "target_character_id": {
          "type": "string",
          "format": "uuid",
          "title": "Target Character Id"
        },
        "expected_target_ownership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Target Ownership Revision"
        },
        "expected_target_lifecycle_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Target Lifecycle Revision"
        },
        "expected_group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Group Revision"
        },
        "expected_membership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Membership Revision"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "target_character_id",
        "expected_target_ownership_revision",
        "expected_target_lifecycle_revision",
        "expected_group_revision",
        "expected_membership_revision"
      ],
      "title": "InviteIn"
    },
    "JoinCode": {
      "properties": {
        "code_id": {
          "anyOf": [
            {
              "type": "string",
              "format": "uuid"
            },
            {
              "type": "null"
            }
          ],
          "title": "Code Id"
        },
        "revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Revision"
        },
        "active": {
          "type": "boolean",
          "title": "Active"
        },
        "visible_to_members": {
          "type": "boolean",
          "title": "Visible To Members"
        },
        "code": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ],
          "title": "Code"
        },
        "created_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ],
          "title": "Created At"
        },
        "regenerate_available_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ],
          "title": "Regenerate Available At"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "code_id",
        "revision",
        "active",
        "visible_to_members",
        "code",
        "created_at",
        "regenerate_available_at"
      ],
      "title": "JoinCode"
    },
    "JoinSubject": {
      "properties": {
        "subject_id": {
          "type": "string",
          "format": "uuid",
          "title": "Subject Id"
        },
        "revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Revision"
        },
        "display": {
          "anyOf": [
            {
              "$ref": "#/components/schemas/CharacterDisplay"
            },
            {
              "type": "null"
            }
          ]
        },
        "application_count": {
          "type": "integer",
          "minimum": 0.0,
          "title": "Application Count"
        },
        "blocked": {
          "type": "boolean",
          "title": "Blocked"
        },
        "blocked_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ],
          "title": "Blocked At"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "subject_id",
        "revision",
        "display",
        "application_count",
        "blocked",
        "blocked_at"
      ],
      "title": "JoinSubject"
    },
    "LeadershipTransferAck": {
      "properties": {
        "group_id": {
          "type": "string",
          "format": "uuid",
          "title": "Group Id"
        },
        "previous_leader_membership_id": {
          "type": "string",
          "format": "uuid",
          "title": "Previous Leader Membership Id"
        },
        "leader_membership_id": {
          "type": "string",
          "format": "uuid",
          "title": "Leader Membership Id"
        },
        "group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Group Revision"
        },
        "members_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Members Revision"
        },
        "previous_leader_membership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Previous Leader Membership Revision"
        },
        "leader_membership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Leader Membership Revision"
        },
        "transferred_at": {
          "type": "string",
          "format": "date-time",
          "title": "Transferred At"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "group_id",
        "previous_leader_membership_id",
        "leader_membership_id",
        "group_revision",
        "members_revision",
        "previous_leader_membership_revision",
        "leader_membership_revision",
        "transferred_at"
      ],
      "title": "LeadershipTransferAck"
    },
    "LeaveGroupIn": {
      "properties": {
        "expected_group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Group Revision"
        },
        "expected_members_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Members Revision"
        },
        "expected_membership_id": {
          "type": "string",
          "format": "uuid",
          "title": "Expected Membership Id"
        },
        "expected_membership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Membership Revision"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "expected_group_revision",
        "expected_members_revision",
        "expected_membership_id",
        "expected_membership_revision"
      ],
      "title": "LeaveGroupIn"
    },
    "LimitValues": {
      "properties": {
        "group_capacity": {
          "type": "integer",
          "minimum": 0.0,
          "title": "Group Capacity"
        },
        "joined_groups": {
          "type": "integer",
          "minimum": 0.0,
          "title": "Joined Groups"
        },
        "raid_rooms": {
          "type": "integer",
          "minimum": 0.0,
          "title": "Raid Rooms"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "group_capacity",
        "joined_groups",
        "raid_rooms"
      ],
      "title": "LimitValues"
    },
    "ManagementPermissions": {
      "properties": {
        "transfer_leadership": {
          "$ref": "#/components/schemas/app__groups__schemas__Permission"
        },
        "leave": {
          "$ref": "#/components/schemas/app__groups__schemas__Permission"
        },
        "disband": {
          "$ref": "#/components/schemas/app__groups__schemas__Permission"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "transfer_leadership",
        "leave",
        "disband"
      ],
      "title": "ManagementPermissions"
    },
    "MyGroupPage": {
      "properties": {
        "items": {
          "items": {
            "$ref": "#/components/schemas/GroupDetail"
          },
          "type": "array",
          "title": "Items"
        },
        "directory_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Directory Revision"
        },
        "next_cursor": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ],
          "title": "Next Cursor"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "items",
        "directory_revision",
        "next_cursor"
      ],
      "title": "MyGroupPage"
    },
    "RejectIn": {
      "properties": {
        "expected_relation_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Relation Revision"
        },
        "expected_group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Group Revision"
        },
        "expected_members_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Members Revision"
        },
        "block_future": {
          "type": "boolean",
          "title": "Block Future",
          "default": false
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "expected_relation_revision",
        "expected_group_revision",
        "expected_members_revision"
      ],
      "title": "RejectIn"
    },
    "RelationAction": {
      "properties": {
        "expected_relation_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Relation Revision"
        },
        "expected_group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Group Revision"
        },
        "expected_members_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Members Revision"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "expected_relation_revision",
        "expected_group_revision",
        "expected_members_revision"
      ],
      "title": "RelationAction"
    },
    "RelationPage": {
      "properties": {
        "items": {
          "items": {
            "$ref": "#/components/schemas/GroupRelation"
          },
          "type": "array",
          "title": "Items"
        },
        "next_cursor": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ],
          "title": "Next Cursor"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "items",
        "next_cursor"
      ],
      "title": "RelationPage"
    },
    "RelationPermissions": {
      "properties": {
        "accept": {
          "$ref": "#/components/schemas/app__groups__schemas__Permission"
        },
        "approve": {
          "$ref": "#/components/schemas/app__groups__schemas__Permission"
        },
        "reject": {
          "$ref": "#/components/schemas/app__groups__schemas__Permission"
        },
        "cancel": {
          "$ref": "#/components/schemas/app__groups__schemas__Permission"
        },
        "block": {
          "$ref": "#/components/schemas/app__groups__schemas__Permission"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "accept",
        "approve",
        "reject",
        "cancel",
        "block"
      ],
      "title": "RelationPermissions"
    },
    "RemoveGroupMemberIn": {
      "properties": {
        "expected_group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Group Revision"
        },
        "expected_members_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Members Revision"
        },
        "expected_membership_id": {
          "type": "string",
          "format": "uuid",
          "title": "Expected Membership Id"
        },
        "expected_membership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Membership Revision"
        },
        "expected_target_membership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Target Membership Revision"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "expected_group_revision",
        "expected_members_revision",
        "expected_membership_id",
        "expected_membership_revision",
        "expected_target_membership_revision"
      ],
      "title": "RemoveGroupMemberIn"
    },
    "TransferLeadershipIn": {
      "properties": {
        "expected_group_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Group Revision"
        },
        "expected_members_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Members Revision"
        },
        "expected_membership_id": {
          "type": "string",
          "format": "uuid",
          "title": "Expected Membership Id"
        },
        "expected_membership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Membership Revision"
        },
        "target_membership_id": {
          "type": "string",
          "format": "uuid",
          "title": "Target Membership Id"
        },
        "expected_target_membership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Expected Target Membership Revision"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "expected_group_revision",
        "expected_members_revision",
        "expected_membership_id",
        "expected_membership_revision",
        "target_membership_id",
        "expected_target_membership_revision"
      ],
      "title": "TransferLeadershipIn"
    },
    "Usage": {
      "properties": {
        "joined_groups": {
          "$ref": "#/components/schemas/UsageMetric"
        },
        "raid_rooms": {
          "$ref": "#/components/schemas/UsageMetric"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "joined_groups",
        "raid_rooms"
      ],
      "title": "Usage"
    },
    "UsageLimits": {
      "properties": {
        "policy_version": {
          "type": "string",
          "const": "member-room-limits-v1",
          "title": "Policy Version"
        },
        "evaluated_at": {
          "type": "string",
          "format": "date-time",
          "title": "Evaluated At"
        },
        "limits_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Limits Revision"
        },
        "usage_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Usage Revision"
        },
        "limit_source": {
          "type": "string",
          "enum": [
            "default",
            "account"
          ],
          "title": "Limit Source"
        },
        "updated_at": {
          "anyOf": [
            {
              "type": "string",
              "format": "date-time"
            },
            {
              "type": "null"
            }
          ],
          "title": "Updated At"
        },
        "limits": {
          "$ref": "#/components/schemas/LimitValues"
        },
        "usage": {
          "$ref": "#/components/schemas/Usage"
        },
        "issues": {
          "items": {
            "$ref": "#/components/schemas/AccountLimitIssue"
          },
          "type": "array",
          "title": "Issues"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "policy_version",
        "evaluated_at",
        "limits_revision",
        "usage_revision",
        "limit_source",
        "updated_at",
        "limits",
        "usage",
        "issues"
      ],
      "title": "UsageLimits"
    },
    "UsageMetric": {
      "properties": {
        "used": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 0.0
            },
            {
              "type": "null"
            }
          ],
          "title": "Used"
        },
        "remaining": {
          "anyOf": [
            {
              "type": "integer",
              "minimum": 0.0
            },
            {
              "type": "null"
            }
          ],
          "title": "Remaining"
        },
        "state": {
          "type": "string",
          "enum": [
            "within",
            "at_limit",
            "exceeded",
            "unavailable"
          ],
          "title": "State"
        },
        "can_increase": {
          "anyOf": [
            {
              "type": "boolean"
            },
            {
              "type": "null"
            }
          ],
          "title": "Can Increase"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "used",
        "remaining",
        "state",
        "can_increase"
      ],
      "title": "UsageMetric"
    },
    "app__groups__schemas__MyMembership": {
      "properties": {
        "membership_id": {
          "type": "string",
          "format": "uuid",
          "title": "Membership Id"
        },
        "role": {
          "type": "string",
          "enum": [
            "leader",
            "member"
          ],
          "title": "Role"
        },
        "revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Revision"
        },
        "joined_at": {
          "type": "string",
          "format": "date-time",
          "title": "Joined At"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "membership_id",
        "role",
        "revision",
        "joined_at"
      ],
      "title": "MyMembership"
    },
    "app__groups__schemas__Permission": {
      "properties": {
        "allowed": {
          "type": "boolean",
          "title": "Allowed"
        },
        "reason": {
          "anyOf": [
            {
              "type": "string"
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
        "allowed",
        "reason"
      ],
      "title": "Permission"
    },
    "app__groups__schemas__Permissions": {
      "properties": {
        "rename": {
          "$ref": "#/components/schemas/app__groups__schemas__Permission"
        },
        "list_members": {
          "$ref": "#/components/schemas/app__groups__schemas__Permission"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "rename",
        "list_members"
      ],
      "title": "Permissions"
    },
    "DisplayInviteCandidate": {
      "properties": {
        "target_character_id": {
          "type": "string",
          "format": "uuid",
          "title": "Target Character Id"
        },
        "display": {
          "$ref": "#/components/schemas/CharacterDisplay"
        },
        "ownership_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Ownership Revision"
        },
        "lifecycle_revision": {
          "type": "integer",
          "minimum": 1.0,
          "title": "Lifecycle Revision"
        },
        "item_level": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ],
          "title": "Item Level"
        },
        "combat_power": {
          "anyOf": [
            {
              "type": "string"
            },
            {
              "type": "null"
            }
          ],
          "title": "Combat Power"
        },
        "character_spec": {
          "$ref": "#/components/schemas/CharacterSpec"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "target_character_id",
        "display",
        "ownership_revision",
        "lifecycle_revision",
        "item_level",
        "combat_power",
        "character_spec"
      ],
      "title": "DisplayInviteCandidate"
    },
    "DisplayInviteCandidates": {
      "properties": {
        "profile": {
          "type": "string",
          "const": "group-display-1",
          "title": "Profile"
        },
        "evaluated_at": {
          "type": "string",
          "format": "date-time",
          "title": "Evaluated At"
        },
        "items": {
          "items": {
            "$ref": "#/components/schemas/DisplayInviteCandidate"
          },
          "type": "array",
          "title": "Items"
        }
      },
      "additionalProperties": false,
      "type": "object",
      "required": [
        "profile",
        "evaluated_at",
        "items"
      ],
      "title": "DisplayInviteCandidates"
    }
  }
}
''';
