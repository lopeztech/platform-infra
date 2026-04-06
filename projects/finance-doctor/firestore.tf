# Firestore database was created manually (Terraform SA lacks appengine/firebase
# permissions needed to manage databases). The (default) database exists in
# australia-southeast1 as FIRESTORE_NATIVE mode.
#
# Runtime access is granted via roles/datastore.user on the app runtime SA
# (see cloudrun.tf).
