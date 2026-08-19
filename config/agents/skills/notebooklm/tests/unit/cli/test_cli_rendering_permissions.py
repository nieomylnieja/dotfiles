"""Display-label policy for share permissions vs. notebook roles (#2125)."""

from __future__ import annotations

from notebooklm.cli.rendering import get_notebook_access_display, get_permission_display
from notebooklm.types import SharePermission


class TestGetPermissionDisplay:
    def test_known_permissions(self):
        assert get_permission_display(SharePermission.OWNER) == "Owner"
        assert get_permission_display(SharePermission.EDITOR) == "Editor"
        assert get_permission_display(SharePermission.VIEWER) == "Viewer"

    def test_unknown_defaults_to_unknown_not_owner(self):
        """The sharing UI must never upgrade an unknown level to "Owner".

        ``get_notebook_access_display`` deliberately degrades to "Owner"; that
        policy belongs to the notebook column alone and must not leak into the
        share list, where mislabelling a permission is security-adjacent.
        """
        assert get_permission_display(None) == "Unknown"
        assert get_permission_display(SharePermission._REMOVE) == "Unknown"

    def test_unknown_label_is_caller_chosen(self):
        assert get_permission_display(None, unknown_label="Owner") == "Owner"


class TestGetNotebookAccessDisplay:
    def test_known_roles(self):
        assert get_notebook_access_display(SharePermission.OWNER) == "Owner"
        assert get_notebook_access_display(SharePermission.EDITOR) == "Editor"
        assert get_notebook_access_display(SharePermission.VIEWER) == "Viewer"

    def test_unstated_role_matches_is_owner_soft_degrade(self):
        assert get_notebook_access_display(None) == "Owner"
