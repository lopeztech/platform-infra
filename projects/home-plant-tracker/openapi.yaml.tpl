swagger: "2.0"
info:
  title: plant-tracker-api
  description: Plant Tracker REST API
  version: "1.0.0"
host: "api.plants.lopezcloud.dev"
basePath: "/"
schemes:
  - https
produces:
  - application/json
consumes:
  - application/json

securityDefinitions:
  api_key:
    type: apiKey
    name: x-api-key
    in: header
  plant_api_key:
    type: apiKey
    name: x-plant-api-key
    in: header

x-google-backend:
  address: ${function_url}
  path_translation: APPEND_PATH_TO_ADDRESS
  jwt_audience: ${function_url}

paths:
  /health:
    get:
      operationId: healthCheck
      summary: Health check
      responses:
        "200":
          description: OK

  /plants:
    get:
      operationId: listPlants
      summary: List all plants
      security:
        - api_key: []
      responses:
        "200":
          description: Array of plants
          schema:
            type: array
            items:
              $ref: "#/definitions/Plant"
    post:
      operationId: createPlant
      summary: Create a plant
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            $ref: "#/definitions/Plant"
      responses:
        "201":
          description: Created plant
          schema:
            $ref: "#/definitions/PlantWithId"
    options:
      operationId: corsPlants
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /plants/recalculate-frequencies:
    post:
      operationId: recalculateFrequencies
      summary: Bulk-recalculate watering frequencies for all plants via Gemini
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 120.0
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
            properties:
              season:
                type: string
              temperature:
                type: number
      responses:
        "200":
          description: Updated plants with recalculated frequencies
    options:
      operationId: corsRecalculateFrequencies
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}:
    get:
      operationId: getPlant
      summary: Get a plant by ID
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Plant
          schema:
            $ref: "#/definitions/PlantWithId"
        "404":
          description: Not found
    put:
      operationId: updatePlant
      summary: Update a plant
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            $ref: "#/definitions/Plant"
      responses:
        "200":
          description: Updated plant
          schema:
            $ref: "#/definitions/PlantWithId"
        "404":
          description: Not found
    delete:
      operationId: deletePlant
      summary: Delete a plant
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: Deleted
        "404":
          description: Not found
    options:
      operationId: corsPlantById
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/photos:
    delete:
      operationId: deletePhoto
      summary: Delete a plant's photo
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Photo deleted
        "404":
          description: Not found
    options:
      operationId: corsDeletePhoto
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /analyse-floorplan:
    post:
      operationId: analyseFloorplan
      summary: Analyse a floorplan image with Gemini and return structured floor/room data
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 110.0
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
            properties:
              imageBase64:
                type: string
              mimeType:
                type: string
      responses:
        "200":
          description: Analysed floor layout
          schema:
            type: object
            properties:
              floors:
                type: array
                items:
                  $ref: "#/definitions/Floor"
    options:
      operationId: corsAnalyseFloorplan
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /analyse:
    post:
      operationId: analysePlant
      summary: Analyse a plant photo with Gemini
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 110.0
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
            properties:
              imageBase64:
                type: string
              mimeType:
                type: string
      responses:
        "200":
          description: Analysis result
          schema:
            type: object
            properties:
              species:
                type: string
              frequencyDays:
                type: integer
              health:
                type: string
              healthReason:
                type: string
              maturity:
                type: string
              recommendations:
                type: array
                items:
                  type: string
    options:
      operationId: corsAnalyse
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /images/upload-url:
    post:
      operationId: getImageUploadUrl
      summary: Get a signed URL to upload an image directly to GCS
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
            properties:
              filename:
                type: string
              contentType:
                type: string
      responses:
        "200":
          description: Signed upload URL and resulting public URL
          schema:
            type: object
            properties:
              uploadUrl:
                type: string
              publicUrl:
                type: string
    options:
      operationId: corsImageUploadUrl
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /config/floors:
    get:
      operationId: getFloors
      summary: Get floors configuration
      security:
        - api_key: []
      responses:
        "200":
          description: Floors config
          schema:
            type: object
            properties:
              floors:
                type: array
                items:
                  $ref: "#/definitions/Floor"
    put:
      operationId: saveFloors
      summary: Save floors configuration
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
            properties:
              floors:
                type: array
                items:
                  $ref: "#/definitions/Floor"
      responses:
        "200":
          description: Saved
    options:
      operationId: corsConfigFloors
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/water:
    post:
      operationId: waterPlant
      summary: Log a watering event for a plant
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 30.0
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Updated plant with new watering event
          schema:
            $ref: "#/definitions/PlantWithId"
        "404":
          description: Not found
    options:
      operationId: corsWaterPlant
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/moisture:
    post:
      operationId: logMoisture
      summary: Log a moisture meter reading for a plant
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Updated plant with new moisture reading
        "400":
          description: Invalid reading (must be integer 1-10)
        "404":
          description: Not found
    options:
      operationId: corsMoisture
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/fertilise:
    post:
      operationId: fertilisePlant
      summary: Log a fertilising event for a plant
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 30.0
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: body
          name: body
          required: false
          schema:
            type: object
            properties:
              productName:
                type: string
              npk:
                type: string
              dilution:
                type: string
              amount:
                type: string
              notes:
                type: string
      responses:
        "200":
          description: Updated plant with new fertiliser log entry
          schema:
            $ref: "#/definitions/PlantWithId"
        "404":
          description: Not found
    options:
      operationId: corsFertilisePlant
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/watering-pattern:
    get:
      operationId: getWateringPattern
      summary: Analyse watering pattern for a plant (heuristic or ML-powered)
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Watering pattern analysis
          schema:
            type: object
            properties:
              pattern:
                type: string
              confidence:
                type: number
              contributingFactors:
                type: array
                items:
                  type: string
        "404":
          description: Not found
    options:
      operationId: corsWateringPattern
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/diagnostic:
    post:
      operationId: diagnosticPlant
      summary: Upload a diagnostic photo and analyse plant health issue
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 110.0
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            type: object
            properties:
              imageBase64:
                type: string
              mimeType:
                type: string
      responses:
        "200":
          description: Diagnostic result with photo URL and analysis
    options:
      operationId: corsDiagnosticPlant
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /recommend:
    post:
      operationId: recommendCare
      summary: Get AI-powered care recommendations for a plant species
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 110.0
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
            properties:
              name:
                type: string
              species:
                type: string
      responses:
        "200":
          description: Care recommendations
    options:
      operationId: corsRecommend
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /recommend-watering:
    post:
      operationId: recommendWatering
      summary: Get AI-powered watering advice for a specific plant
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 110.0
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
            properties:
              name:
                type: string
              species:
                type: string
      responses:
        "200":
          description: Watering recommendations
    options:
      operationId: corsRecommendWatering
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /recommend-fertiliser:
    post:
      operationId: recommendFertiliser
      summary: Get AI-powered fertiliser recommendations for a specific plant
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 110.0
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
            properties:
              name:
                type: string
              species:
                type: string
      responses:
        "200":
          description: Fertiliser recommendations
    options:
      operationId: corsRecommendFertiliser
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /billing/subscription:
    get:
      operationId: getSubscription
      summary: Return the caller's current tier, status, quotas, and usage
      security:
        - api_key: []
      responses:
        "200":
          description: Subscription + usage snapshot
    options:
      operationId: corsGetSubscription
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /billing/create-checkout-session:
    post:
      operationId: createCheckoutSession
      summary: Start a Stripe Checkout session for a tier upgrade
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 30.0
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
            properties:
              tier:
                type: string
              interval:
                type: string
      responses:
        "200":
          description: Returns the Stripe Checkout redirect URL
        "503":
          description: Billing not enabled
    options:
      operationId: corsCreateCheckoutSession
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /billing/create-portal-session:
    post:
      operationId: createPortalSession
      summary: Open the Stripe Customer Portal for plan management
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 30.0
      security:
        - api_key: []
      responses:
        "200":
          description: Returns the Stripe Customer Portal URL
    options:
      operationId: corsCreatePortalSession
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /billing/webhook:
    post:
      operationId: stripeWebhook
      summary: Stripe webhook — signed with STRIPE_WEBHOOK_SECRET (no API key)
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 30.0
      # Intentionally no `security` — Stripe signs webhooks with its own
      # secret, verified by the backend via constructEvent().
      responses:
        "200":
          description: Event accepted (or ignored / duplicate)
        "400":
          description: Signature verification failed

  /config/floorplan:
    get:
      operationId: getFloorplan
      summary: Get the saved floorplan image URL
      security:
        - api_key: []
      responses:
        "200":
          description: Floorplan config
          schema:
            type: object
            properties:
              imageUrl:
                type: string
    put:
      operationId: saveFloorplan
      summary: Save the floorplan image URL
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
            properties:
              imageUrl:
                type: string
      responses:
        "200":
          description: Saved
    options:
      operationId: corsConfigFloorplan
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  # ── Profile / persona ──────────────────────────────────────────────────────
  /profile:
    get:
      operationId: getProfile
      summary: Get user profile (accountType — household / landscaper / both)
      security:
        - api_key: []
      responses:
        "200":
          description: Profile snapshot
    put:
      operationId: setProfile
      summary: Update user profile (accountType)
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
            properties:
              accountType:
                type: string
      responses:
        "200":
          description: Updated profile
        "400":
          description: Invalid accountType
    options:
      operationId: corsProfile
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  # ── Account ────────────────────────────────────────────────────────────────
  /account:
    delete:
      operationId: deleteAccount
      summary: Delete the caller's account and all associated data
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 60.0
      security:
        - api_key: []
      responses:
        "204":
          description: Deleted
    options:
      operationId: corsAccount
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /account/export:
    get:
      operationId: exportAccount
      summary: GDPR data export of all account data
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 60.0
      security:
        - api_key: []
      responses:
        "200":
          description: Full account export (JSON)
    options:
      operationId: corsAccountExport
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /account/trial/start:
    post:
      operationId: startTrial
      summary: Start the 7-day home_pro trial for a new account
      security:
        - api_key: []
      responses:
        "201":
          description: Trial started
        "200":
          description: Trial already exists
    options:
      operationId: corsAccountTrialStart
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  # ── Households (multi-user shared access) ──────────────────────────────────
  /households:
    get:
      operationId: listHouseholds
      summary: List households the caller is a member of
      security:
        - api_key: []
      responses:
        "200":
          description: Households + active selection
    post:
      operationId: createHousehold
      summary: Create a new household
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
            properties:
              name:
                type: string
      responses:
        "201":
          description: Created household
    options:
      operationId: corsHouseholds
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /households/current:
    get:
      operationId: getCurrentHousehold
      summary: Get the caller's currently active household
      security:
        - api_key: []
      responses:
        "200":
          description: Active household
    options:
      operationId: corsHouseholdsCurrent
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /households/join:
    post:
      operationId: joinHousehold
      summary: Join a household via invite code
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
            properties:
              code:
                type: string
      responses:
        "200":
          description: Joined household
        "404":
          description: Invite not found / expired
    options:
      operationId: corsHouseholdsJoin
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /households/{householdId}:
    put:
      operationId: renameHousehold
      summary: Rename a household
      security:
        - api_key: []
      parameters:
        - in: path
          name: householdId
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            type: object
            properties:
              name:
                type: string
      responses:
        "200":
          description: Updated household
    options:
      operationId: corsHouseholdById
      summary: CORS preflight
      parameters:
        - in: path
          name: householdId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /households/{householdId}/switch:
    post:
      operationId: switchHousehold
      summary: Switch the caller's active household
      security:
        - api_key: []
      parameters:
        - in: path
          name: householdId
          required: true
          type: string
      responses:
        "200":
          description: Switched
    options:
      operationId: corsHouseholdSwitch
      summary: CORS preflight
      parameters:
        - in: path
          name: householdId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /households/{householdId}/invites:
    post:
      operationId: createHouseholdInvite
      summary: Create an invite code for a household
      security:
        - api_key: []
      parameters:
        - in: path
          name: householdId
          required: true
          type: string
        - in: body
          name: body
          required: false
          schema:
            type: object
            properties:
              role:
                type: string
      responses:
        "201":
          description: Invite created
    options:
      operationId: corsHouseholdInvites
      summary: CORS preflight
      parameters:
        - in: path
          name: householdId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /households/{householdId}/members/{memberUserId}:
    put:
      operationId: setHouseholdMemberRole
      summary: Update a member's role
      security:
        - api_key: []
      parameters:
        - in: path
          name: householdId
          required: true
          type: string
        - in: path
          name: memberUserId
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            type: object
            properties:
              role:
                type: string
      responses:
        "200":
          description: Updated
    delete:
      operationId: removeHouseholdMember
      summary: Remove a member from a household
      security:
        - api_key: []
      parameters:
        - in: path
          name: householdId
          required: true
          type: string
        - in: path
          name: memberUserId
          required: true
          type: string
      responses:
        "204":
          description: Removed
    options:
      operationId: corsHouseholdMember
      summary: CORS preflight
      parameters:
        - in: path
          name: householdId
          required: true
          type: string
        - in: path
          name: memberUserId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  # ── Properties (landscaper multi-property) ─────────────────────────────────
  /properties:
    get:
      operationId: listProperties
      summary: List the caller's properties
      security:
        - api_key: []
      responses:
        "200":
          description: Property list
    post:
      operationId: createProperty
      summary: Create a property
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "201":
          description: Created
    options:
      operationId: corsProperties
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /properties/{propertyId}:
    get:
      operationId: getProperty
      summary: Get a property by ID
      security:
        - api_key: []
      parameters:
        - in: path
          name: propertyId
          required: true
          type: string
      responses:
        "200":
          description: Property
        "404":
          description: Not found
    put:
      operationId: updateProperty
      summary: Update a property
      security:
        - api_key: []
      parameters:
        - in: path
          name: propertyId
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "200":
          description: Updated
    delete:
      operationId: archiveProperty
      summary: Archive a property
      security:
        - api_key: []
      parameters:
        - in: path
          name: propertyId
          required: true
          type: string
      responses:
        "204":
          description: Archived
    options:
      operationId: corsPropertyById
      summary: CORS preflight
      parameters:
        - in: path
          name: propertyId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /properties/{propertyId}/restore:
    post:
      operationId: restoreProperty
      summary: Restore an archived property
      security:
        - api_key: []
      parameters:
        - in: path
          name: propertyId
          required: true
          type: string
      responses:
        "200":
          description: Restored
    options:
      operationId: corsPropertyRestore
      summary: CORS preflight
      parameters:
        - in: path
          name: propertyId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  # ── Team RBAC ──────────────────────────────────────────────────────────────
  /team:
    get:
      operationId: listTeam
      summary: List landscaper org team members
      security:
        - api_key: []
      responses:
        "200":
          description: Team members
    options:
      operationId: corsTeam
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /team/invite:
    post:
      operationId: inviteTeamMember
      summary: Invite a new team member to the landscaper org
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
            properties:
              email:
                type: string
              role:
                type: string
      responses:
        "201":
          description: Invite created
        "402":
          description: Quota exceeded
        "403":
          description: Not the org owner
    options:
      operationId: corsTeamInvite
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /team/accept:
    post:
      operationId: acceptTeamInvite
      summary: Accept a team invite via token
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
            properties:
              token:
                type: string
      responses:
        "200":
          description: Accepted
        "404":
          description: Invite not found / expired
    options:
      operationId: corsTeamAccept
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /team/{memberUid}:
    patch:
      operationId: updateTeamMember
      summary: Update a team member's role
      security:
        - api_key: []
      parameters:
        - in: path
          name: memberUid
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            type: object
            properties:
              role:
                type: string
      responses:
        "200":
          description: Updated
    delete:
      operationId: removeTeamMember
      summary: Remove a team member
      security:
        - api_key: []
      parameters:
        - in: path
          name: memberUid
          required: true
          type: string
      responses:
        "204":
          description: Removed
    options:
      operationId: corsTeamMember
      summary: CORS preflight
      parameters:
        - in: path
          name: memberUid
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /me/orgs:
    get:
      operationId: listMyOrgs
      summary: List the orgs the caller is a member of (own + invited landscaper orgs)
      security:
        - api_key: []
      responses:
        "200":
          description: Org list
    options:
      operationId: corsMeOrgs
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  # ── Visits (landscaper visit lifecycle) ────────────────────────────────────
  /visits:
    get:
      operationId: listVisits
      summary: List visits (filterable by status / property)
      security:
        - api_key: []
      responses:
        "200":
          description: Visit list
    post:
      operationId: createVisit
      summary: Schedule a new visit
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "201":
          description: Created
    options:
      operationId: corsVisits
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /visits/{visitId}:
    get:
      operationId: getVisit
      summary: Get a visit by ID
      security:
        - api_key: []
      parameters:
        - in: path
          name: visitId
          required: true
          type: string
      responses:
        "200":
          description: Visit
        "404":
          description: Not found
    put:
      operationId: updateVisit
      summary: Update a scheduled visit
      security:
        - api_key: []
      parameters:
        - in: path
          name: visitId
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "200":
          description: Updated
    delete:
      operationId: deleteVisit
      summary: Delete / cancel a visit
      security:
        - api_key: []
      parameters:
        - in: path
          name: visitId
          required: true
          type: string
      responses:
        "204":
          description: Deleted
    options:
      operationId: corsVisitById
      summary: CORS preflight
      parameters:
        - in: path
          name: visitId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /visits/{visitId}/check-in:
    post:
      operationId: checkInVisit
      summary: Mark visit check-in (started)
      security:
        - api_key: []
      parameters:
        - in: path
          name: visitId
          required: true
          type: string
      responses:
        "200":
          description: Checked in
    options:
      operationId: corsVisitCheckIn
      summary: CORS preflight
      parameters:
        - in: path
          name: visitId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /visits/{visitId}/check-out:
    post:
      operationId: checkOutVisit
      summary: Mark visit check-out
      security:
        - api_key: []
      parameters:
        - in: path
          name: visitId
          required: true
          type: string
      responses:
        "200":
          description: Checked out
    options:
      operationId: corsVisitCheckOut
      summary: CORS preflight
      parameters:
        - in: path
          name: visitId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /visits/{visitId}/complete:
    post:
      operationId: completeVisit
      summary: Mark visit complete with notes / work-done log
      security:
        - api_key: []
      parameters:
        - in: path
          name: visitId
          required: true
          type: string
        - in: body
          name: body
          required: false
          schema:
            type: object
      responses:
        "200":
          description: Completed
    options:
      operationId: corsVisitComplete
      summary: CORS preflight
      parameters:
        - in: path
          name: visitId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /visits.ics:
    get:
      operationId: visitsIcs
      summary: Visits calendar feed (iCalendar) — token-authenticated
      responses:
        "200":
          description: iCalendar feed
        "401":
          description: Invalid / missing token

  /visits/ics-token:
    get:
      operationId: getVisitsIcsToken
      summary: Get / rotate the iCalendar feed token for the caller
      security:
        - api_key: []
      responses:
        "200":
          description: Token
    options:
      operationId: corsVisitsIcsToken
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  # ── API keys (public REST API management) ──────────────────────────────────
  /api-keys:
    get:
      operationId: listApiKeys
      summary: List the caller's public API keys
      security:
        - api_key: []
      responses:
        "200":
          description: API key list (hash + prefix only; no secret)
    post:
      operationId: createApiKey
      summary: Create a new public API key (returned plaintext once)
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
            properties:
              name:
                type: string
      responses:
        "201":
          description: Created (with plaintext key)
        "402":
          description: Tier upgrade required
    options:
      operationId: corsApiKeys
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /api-keys/{keyId}:
    delete:
      operationId: revokeApiKey
      summary: Revoke a public API key
      security:
        - api_key: []
      parameters:
        - in: path
          name: keyId
          required: true
          type: string
      responses:
        "204":
          description: Revoked
    options:
      operationId: corsApiKeyById
      summary: CORS preflight
      parameters:
        - in: path
          name: keyId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  # ── Public REST API (x-plant-api-key) ──────────────────────────────────────
  /api/v1/plants:
    get:
      operationId: publicListPlants
      summary: Public API — list plants
      security:
        - plant_api_key: []
      responses:
        "200":
          description: Plant list
        "401":
          description: Invalid API key
    options:
      operationId: corsPublicListPlants
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /api/v1/plants/{plantId}:
    get:
      operationId: publicGetPlant
      summary: Public API — get a plant by ID
      security:
        - plant_api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Plant
        "404":
          description: Not found
    options:
      operationId: corsPublicPlantById
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /api/v1/plants/{plantId}/water:
    post:
      operationId: publicWaterPlant
      summary: Public API — log a watering event
      security:
        - plant_api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Updated plant
        "404":
          description: Not found
    options:
      operationId: corsPublicWaterPlant
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /api/v1/plants/{plantId}/care-score:
    get:
      operationId: publicCareScore
      summary: Public API — care score for a plant
      security:
        - plant_api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Care score
        "402":
          description: Tier upgrade required
    options:
      operationId: corsPublicCareScore
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  # ── Climate / hardiness (PR #366) ──────────────────────────────────────────
  /climate/lookup:
    get:
      operationId: climateLookup
      summary: Köppen climate classification + frost dates from Open-Meteo
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 30.0
      security:
        - api_key: []
      responses:
        "200":
          description: Climate classification
    options:
      operationId: corsClimateLookup
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /climate/plant-compatibility:
    get:
      operationId: climateCompatibility
      summary: Gemini hardy / tender / unsuitable verdict for a plant + climate
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 110.0
      security:
        - api_key: []
      responses:
        "200":
          description: Compatibility verdict
    options:
      operationId: corsClimateCompatibility
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  # ── Companion planting / raised-bed grids (PR #366) ────────────────────────
  /companions:
    get:
      operationId: getCompanions
      summary: Companion planting matrix
      security:
        - api_key: []
      responses:
        "200":
          description: Companion data
    options:
      operationId: corsCompanions
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /config/beds/{roomId}/compatibility:
    get:
      operationId: getBedCompatibility
      summary: Compatibility overlay for a raised-bed room
      security:
        - api_key: []
      parameters:
        - in: path
          name: roomId
          required: true
          type: string
      responses:
        "200":
          description: 8-cell neighbourhood compatibility scan
    options:
      operationId: corsBedCompatibility
      summary: CORS preflight
      parameters:
        - in: path
          name: roomId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/bed-placement:
    post:
      operationId: setBedPlacement
      summary: Place a plant in a raised-bed grid cell
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "200":
          description: Placed
    delete:
      operationId: removeBedPlacement
      summary: Remove a plant's bed placement
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: Removed
    options:
      operationId: corsBedPlacement
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  # ── Branding (landscaper white-label) ──────────────────────────────────────
  /config/branding:
    get:
      operationId: getBranding
      summary: Get business branding (logo, colour, contact info)
      security:
        - api_key: []
      responses:
        "200":
          description: Branding config
    put:
      operationId: saveBranding
      summary: Save business branding
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "200":
          description: Saved
        "402":
          description: Tier upgrade required
    options:
      operationId: corsConfigBranding
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  # ── Propagations ───────────────────────────────────────────────────────────
  /propagations:
    get:
      operationId: listPropagations
      summary: List propagations
      security:
        - api_key: []
      responses:
        "200":
          description: Propagation list
    post:
      operationId: createPropagation
      summary: Create a propagation
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "201":
          description: Created
    options:
      operationId: corsPropagations
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /propagations/{propagationId}:
    put:
      operationId: updatePropagation
      summary: Update a propagation
      security:
        - api_key: []
      parameters:
        - in: path
          name: propagationId
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "200":
          description: Updated
    delete:
      operationId: deletePropagation
      summary: Delete a propagation
      security:
        - api_key: []
      parameters:
        - in: path
          name: propagationId
          required: true
          type: string
      responses:
        "204":
          description: Deleted
    options:
      operationId: corsPropagationById
      summary: CORS preflight
      parameters:
        - in: path
          name: propagationId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /propagations/{propagationId}/promote:
    post:
      operationId: promotePropagation
      summary: Convert a propagation into an independent plant
      security:
        - api_key: []
      parameters:
        - in: path
          name: propagationId
          required: true
          type: string
      responses:
        "200":
          description: Promoted to plant
    options:
      operationId: corsPropagationPromote
      summary: CORS preflight
      parameters:
        - in: path
          name: propagationId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /propagation/stats:
    get:
      operationId: propagationStats
      summary: Aggregate propagation success-rate stats
      security:
        - api_key: []
      responses:
        "200":
          description: Stats
    options:
      operationId: corsPropagationStats
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/lineage:
    get:
      operationId: getPlantLineage
      summary: Ancestors + descendants of a plant (depth ≤ 3, cycle-guarded)
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Lineage tree
    options:
      operationId: corsPlantLineage
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  # ── QR / scan public access ────────────────────────────────────────────────
  /scan/{shortCode}:
    get:
      operationId: resolveScan
      summary: Resolve a QR short-code to a plant (public, no auth)
      parameters:
        - in: path
          name: shortCode
          required: true
          type: string
      responses:
        "200":
          description: Plant
        "404":
          description: Not found

  /plants/{plantId}/short-code:
    get:
      operationId: getPlantShortCode
      summary: Get / generate the QR short-code for a plant
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Short-code + QR URL
    options:
      operationId: corsPlantShortCode
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  # ── Per-plant care logs: measurements ──────────────────────────────────────
  /plants/{plantId}/measurements:
    get:
      operationId: listMeasurements
      summary: List growth measurements for a plant
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Measurement list
    post:
      operationId: createMeasurement
      summary: Record a growth measurement
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "201":
          description: Created
    options:
      operationId: corsMeasurements
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/measurements/{measurementId}:
    delete:
      operationId: deleteMeasurement
      summary: Delete a measurement
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: measurementId
          required: true
          type: string
      responses:
        "204":
          description: Deleted
    options:
      operationId: corsMeasurementById
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: measurementId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  # ── Per-plant care logs: phenology ─────────────────────────────────────────
  /plants/{plantId}/phenology:
    get:
      operationId: listPhenology
      summary: List phenology events for a plant
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Phenology event list
    post:
      operationId: createPhenology
      summary: Record a phenology event
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "201":
          description: Created
    options:
      operationId: corsPhenology
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/phenology/{eventId}:
    delete:
      operationId: deletePhenology
      summary: Delete a phenology event
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: eventId
          required: true
          type: string
      responses:
        "204":
          description: Deleted
    options:
      operationId: corsPhenologyById
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: eventId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  # ── Per-plant care logs: journal ───────────────────────────────────────────
  /plants/{plantId}/journal:
    get:
      operationId: listJournal
      summary: List journal entries for a plant
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Journal entries
    post:
      operationId: createJournalEntry
      summary: Add a journal entry
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "201":
          description: Created
    options:
      operationId: corsJournal
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/journal/{entryId}:
    put:
      operationId: updateJournalEntry
      summary: Update a journal entry
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: entryId
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "200":
          description: Updated
    delete:
      operationId: deleteJournalEntry
      summary: Delete a journal entry
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: entryId
          required: true
          type: string
      responses:
        "204":
          description: Deleted
    options:
      operationId: corsJournalById
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: entryId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  # ── Per-plant care logs: harvests ──────────────────────────────────────────
  /plants/{plantId}/harvests:
    get:
      operationId: listHarvests
      summary: List harvests for a plant
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Harvest list
    post:
      operationId: createHarvest
      summary: Record a harvest
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "201":
          description: Created
    options:
      operationId: corsHarvests
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/harvests/{harvestId}:
    delete:
      operationId: deleteHarvest
      summary: Delete a harvest
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: harvestId
          required: true
          type: string
      responses:
        "204":
          description: Deleted
    options:
      operationId: corsHarvestById
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: harvestId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  # ── Per-plant care logs: soil ──────────────────────────────────────────────
  /plants/{plantId}/soil-tests:
    get:
      operationId: listSoilTests
      summary: List soil tests for a plant
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Soil test list
    post:
      operationId: createSoilTest
      summary: Record a soil test
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "201":
          description: Created
    options:
      operationId: corsSoilTests
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/soil-tests/{testId}:
    delete:
      operationId: deleteSoilTest
      summary: Delete a soil test
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: testId
          required: true
          type: string
      responses:
        "204":
          description: Deleted
    options:
      operationId: corsSoilTestById
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: testId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/amendments:
    get:
      operationId: listAmendments
      summary: List soil amendments for a plant
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Amendment list
    post:
      operationId: createAmendment
      summary: Record a soil amendment
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "201":
          description: Created
    options:
      operationId: corsAmendments
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/amendments/{amendmentId}:
    delete:
      operationId: deleteAmendment
      summary: Delete a soil amendment
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: amendmentId
          required: true
          type: string
      responses:
        "204":
          description: Deleted
    options:
      operationId: corsAmendmentById
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: amendmentId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/substrate-changes:
    get:
      operationId: listSubstrateChanges
      summary: List substrate changes for a plant
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Substrate change list
    post:
      operationId: createSubstrateChange
      summary: Record a substrate change
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "201":
          description: Created
    options:
      operationId: corsSubstrateChanges
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/soil-insight:
    get:
      operationId: getSoilInsight
      summary: Rule-based pH verdict + Gemini one-sentence rationale
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 60.0
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Soil insight
    options:
      operationId: corsSoilInsight
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  # ── Per-plant care logs: pest / disease incidents ──────────────────────────
  /plants/{plantId}/incidents:
    get:
      operationId: listIncidents
      summary: List pest/disease incidents for a plant
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Incident list
    post:
      operationId: createIncident
      summary: Log a pest/disease incident
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "201":
          description: Created
    options:
      operationId: corsIncidents
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/incidents/{incidentId}:
    put:
      operationId: updateIncident
      summary: Update an incident
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: incidentId
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "200":
          description: Updated
    delete:
      operationId: deleteIncident
      summary: Delete an incident
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: incidentId
          required: true
          type: string
      responses:
        "204":
          description: Deleted
    options:
      operationId: corsIncidentById
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: incidentId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/incidents/{incidentId}/treatments:
    post:
      operationId: addIncidentTreatment
      summary: Record a treatment for an incident
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: incidentId
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "201":
          description: Treatment recorded
    options:
      operationId: corsIncidentTreatments
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: incidentId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/incidents/{incidentId}/resolve:
    post:
      operationId: resolveIncident
      summary: Mark an incident resolved
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: incidentId
          required: true
          type: string
      responses:
        "200":
          description: Resolved
    options:
      operationId: corsIncidentResolve
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: incidentId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  # ── Cross-plant outbreaks ──────────────────────────────────────────────────
  /outbreaks:
    get:
      operationId: listOutbreaks
      summary: Cross-plant outbreak aggregation
      security:
        - api_key: []
      responses:
        "200":
          description: Outbreak list
    options:
      operationId: corsOutbreaks
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /outbreaks/{outbreakId}/treat:
    post:
      operationId: treatOutbreak
      summary: Record treatment across all plants in an outbreak
      security:
        - api_key: []
      parameters:
        - in: path
          name: outbreakId
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "200":
          description: Treated
    options:
      operationId: corsOutbreakTreat
      summary: CORS preflight
      parameters:
        - in: path
          name: outbreakId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /outbreaks/{outbreakId}/resolve:
    post:
      operationId: resolveOutbreak
      summary: Resolve an outbreak across all affected plants
      security:
        - api_key: []
      parameters:
        - in: path
          name: outbreakId
          required: true
          type: string
      responses:
        "200":
          description: Resolved
    options:
      operationId: corsOutbreakResolve
      summary: CORS preflight
      parameters:
        - in: path
          name: outbreakId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  # ── Wildlife observations ──────────────────────────────────────────────────
  /plants/{plantId}/wildlifeObservations:
    get:
      operationId: listWildlifeObservations
      summary: List pollinator / wildlife observations for a plant
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Observation list
    post:
      operationId: createWildlifeObservation
      summary: Record a wildlife / pollinator observation
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "201":
          description: Created
    options:
      operationId: corsWildlifeObservations
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/wildlifeObservations/{obsId}:
    delete:
      operationId: deleteWildlifeObservation
      summary: Delete an observation
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: obsId
          required: true
          type: string
      responses:
        "204":
          description: Deleted
    options:
      operationId: corsWildlifeObservationById
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: obsId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  # ── Blooms / lifecycle / dormancy ──────────────────────────────────────────
  /plants/{plantId}/blooms:
    get:
      operationId: listBlooms
      summary: List bloom events for a plant
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Bloom list
    post:
      operationId: createBloom
      summary: Record the start of a bloom
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "201":
          description: Created
    options:
      operationId: corsBlooms
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/blooms/{bloomId}:
    put:
      operationId: updateBloom
      summary: Update a bloom event
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: bloomId
          required: true
          type: string
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "200":
          description: Updated
    options:
      operationId: corsBloomById
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: bloomId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/blooms/{bloomId}/end:
    post:
      operationId: endBloom
      summary: Mark the end of a bloom event
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: bloomId
          required: true
          type: string
      responses:
        "200":
          description: Bloom ended
    options:
      operationId: corsBloomEnd
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: path
          name: bloomId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/lifecycle:
    get:
      operationId: getLifecycle
      summary: Get lifecycle events (prune / repot history)
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Lifecycle events
    options:
      operationId: corsLifecycle
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/lifecycle/prune:
    post:
      operationId: recordPrune
      summary: Record a pruning event
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: body
          name: body
          required: false
          schema:
            type: object
      responses:
        "201":
          description: Recorded
    options:
      operationId: corsLifecyclePrune
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/lifecycle/repot:
    post:
      operationId: recordRepot
      summary: Record a repot event
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: body
          name: body
          required: false
          schema:
            type: object
      responses:
        "201":
          description: Recorded
    options:
      operationId: corsLifecycleRepot
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/dormancy/enter:
    post:
      operationId: enterDormancy
      summary: Mark a plant as entering dormancy
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: body
          name: body
          required: false
          schema:
            type: object
      responses:
        "200":
          description: Entered dormancy
    options:
      operationId: corsDormancyEnter
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/dormancy/exit:
    post:
      operationId: exitDormancy
      summary: Mark a plant as exiting dormancy
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
        - in: body
          name: body
          required: false
          schema:
            type: object
      responses:
        "200":
          description: Exited dormancy
    options:
      operationId: corsDormancyExit
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  # ── Per-plant ML / analytics ───────────────────────────────────────────────
  /plants/{plantId}/anomaly:
    get:
      operationId: getPlantAnomaly
      summary: Per-plant anomaly score
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Anomaly score
    options:
      operationId: corsPlantAnomaly
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/health-prediction:
    get:
      operationId: getHealthPrediction
      summary: Health prediction for a plant (home_pro+)
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Health prediction
        "402":
          description: Tier upgrade required
    options:
      operationId: corsHealthPrediction
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/seasonal-adjustment:
    get:
      operationId: getSeasonalAdjustment
      summary: Seasonal frequency-multiplier adjustment for a plant
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Seasonal adjustment
    options:
      operationId: corsSeasonalAdjustment
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/care-score:
    get:
      operationId: getCareScore
      summary: Compute / return cached care score for a plant
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Care score
    options:
      operationId: corsCareScore
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/watering-recommendation:
    get:
      operationId: getWateringRecommendation
      summary: AI-powered watering recommendation for a plant
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 110.0
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Watering recommendation
    options:
      operationId: corsWateringRecommendation
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /plants/{plantId}/waterings:
    get:
      operationId: listWaterings
      summary: Paginated watering history for a plant
      security:
        - api_key: []
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Watering log
    options:
      operationId: corsWaterings
      summary: CORS preflight
      parameters:
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  # ── ML / cross-plant analytics ─────────────────────────────────────────────
  /ml/care-scores:
    get:
      operationId: listCareScores
      summary: Care scores for all plants (home_pro+)
      security:
        - api_key: []
      responses:
        "200":
          description: Care scores
        "402":
          description: Tier upgrade required
    options:
      operationId: corsMlCareScores
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /ml/status:
    get:
      operationId: mlStatus
      summary: ML model deployment status (no auth)
      responses:
        "200":
          description: Status

  /ml/export:
    get:
      operationId: mlExport
      summary: Full user-data export for ML training (no auth — token via query)
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 60.0
      responses:
        "200":
          description: User data export

  /ml/anomaly-scan:
    post:
      operationId: mlAnomalyScan
      summary: Background anomaly scan across all plants (no auth — internal)
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 110.0
      responses:
        "200":
          description: Scan complete

  /species/{name}/cluster:
    get:
      operationId: getSpeciesCluster
      summary: Care-pattern cluster for a species
      security:
        - api_key: []
      parameters:
        - in: path
          name: name
          required: true
          type: string
      responses:
        "200":
          description: Species cluster
    options:
      operationId: corsSpeciesCluster
      summary: CORS preflight
      parameters:
        - in: path
          name: name
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  # ── AI extras ──────────────────────────────────────────────────────────────
  /analyse-with-hint:
    post:
      operationId: analyseWithHint
      summary: Analyse a photo with a species hint
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 110.0
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
            properties:
              imageBase64:
                type: string
              mimeType:
                type: string
              speciesHint:
                type: string
      responses:
        "200":
          description: Analysis result
    options:
      operationId: corsAnalyseWithHint
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /plants/identify:
    post:
      operationId: identifyPlant
      summary: Identify a plant from up to 3 photos
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 110.0
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
            properties:
              images:
                type: array
                items:
                  type: object
      responses:
        "200":
          description: Identification result
    options:
      operationId: corsIdentifyPlant
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /recommend-propagation:
    post:
      operationId: recommendPropagation
      summary: AI-powered propagation recommendations for a species
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 110.0
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "200":
          description: Propagation recommendations
    options:
      operationId: corsRecommendPropagation
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  # ── Exports / imports (home_pro+) ──────────────────────────────────────────
  /export/plants:
    get:
      operationId: exportPlants
      summary: Export plants as CSV / XLSX
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 60.0
      security:
        - api_key: []
      responses:
        "200":
          description: Export file
        "402":
          description: Tier upgrade required
    options:
      operationId: corsExportPlants
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /export/watering-history:
    get:
      operationId: exportWateringHistory
      summary: Export watering history
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 60.0
      security:
        - api_key: []
      responses:
        "200":
          description: Export file
        "402":
          description: Tier upgrade required
    options:
      operationId: corsExportWateringHistory
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /export/care-schedule:
    get:
      operationId: exportCareSchedule
      summary: Export care schedule
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 60.0
      security:
        - api_key: []
      responses:
        "200":
          description: Export file
        "402":
          description: Tier upgrade required
    options:
      operationId: corsExportCareSchedule
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /import/plants:
    post:
      operationId: importPlants
      summary: Bulk import plants from CSV / XLSX
      x-google-backend:
        address: ${function_url}
        path_translation: APPEND_PATH_TO_ADDRESS
        jwt_audience: ${function_url}
        deadline: 110.0
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "200":
          description: Import result
        "402":
          description: Tier upgrade required
    options:
      operationId: corsImportPlants
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /import/plants/template:
    get:
      operationId: importPlantsTemplate
      summary: Download the CSV template for plant import
      security:
        - api_key: []
      responses:
        "200":
          description: CSV template
    options:
      operationId: corsImportPlantsTemplate
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  # ── Portal (landscaper public client portal) ───────────────────────────────
  /portal/generate:
    post:
      operationId: portalGenerate
      summary: Generate a public client-portal token (landscaper_pro)
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: false
          schema:
            type: object
            properties:
              label:
                type: string
      responses:
        "201":
          description: Token created
        "402":
          description: Tier upgrade required
    options:
      operationId: corsPortalGenerate
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /portal/{token}:
    get:
      operationId: portalView
      summary: Public client-portal view (no auth — token in path)
      parameters:
        - in: path
          name: token
          required: true
          type: string
      responses:
        "200":
          description: Portal data
        "404":
          description: Invalid token

  # ── Sit-sessions (plant-sitter share) ──────────────────────────────────────
  /sit-sessions:
    get:
      operationId: listSitSessions
      summary: List the caller's sit-session shares
      security:
        - api_key: []
      responses:
        "200":
          description: Sit-session list
    post:
      operationId: createSitSession
      summary: Create a sit-session share
      security:
        - api_key: []
      parameters:
        - in: body
          name: body
          required: true
          schema:
            type: object
      responses:
        "201":
          description: Created
    options:
      operationId: corsSitSessions
      summary: CORS preflight
      responses:
        "204":
          description: CORS preflight

  /sit-sessions/{sessionId}:
    delete:
      operationId: deleteSitSession
      summary: Revoke a sit-session share
      security:
        - api_key: []
      parameters:
        - in: path
          name: sessionId
          required: true
          type: string
      responses:
        "204":
          description: Deleted
    options:
      operationId: corsSitSessionById
      summary: CORS preflight
      parameters:
        - in: path
          name: sessionId
          required: true
          type: string
      responses:
        "204":
          description: CORS preflight

  /sit/{token}:
    get:
      operationId: sitView
      summary: Public sitter view (no auth — token in path)
      parameters:
        - in: path
          name: token
          required: true
          type: string
      responses:
        "200":
          description: Sitter view
        "404":
          description: Invalid / revoked token

  /sit/{token}/water/{plantId}:
    post:
      operationId: sitWater
      summary: Sitter logs a watering event (no user auth — token-based)
      parameters:
        - in: path
          name: token
          required: true
          type: string
        - in: path
          name: plantId
          required: true
          type: string
      responses:
        "200":
          description: Watered

definitions:
  Plant:
    type: object
    properties:
      name:
        type: string
      species:
        type: string
      room:
        type: string
      x:
        type: number
        format: float
      y:
        type: number
        format: float
      lastWatered:
        type: string
      frequencyDays:
        type: integer
      notes:
        type: string
      health:
        type: string
      maturity:
        type: string
      recommendations:
        type: array
        items:
          type: string
      imageUrl:
        type: string
  Floor:
    type: object
    properties:
      id:
        type: string
      name:
        type: string
      order:
        type: integer
      type:
        type: string
      imageUrl:
        type: string
  PlantWithId:
    allOf:
      - $ref: "#/definitions/Plant"
      - type: object
        properties:
          id:
            type: string
          createdAt:
            type: string
          updatedAt:
            type: string
