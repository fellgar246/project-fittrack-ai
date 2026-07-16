"""add progress photos table

Revision ID: a8c3b1d92e47
Revises: f16d4cefefc2
Create Date: 2026-07-16 03:45:00.000000

"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a8c3b1d92e47"
down_revision: Union[str, Sequence[str], None] = "f16d4cefefc2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    op.create_table(
        "progress_photos",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("user_id", sa.UUID(), nullable=False),
        sa.Column("blob_name", sa.String(length=512), nullable=False),
        sa.Column("captured_at", sa.Date(), nullable=False),
        sa.Column("content_type", sa.String(length=64), nullable=False),
        sa.Column("size_bytes", sa.BigInteger(), nullable=False),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("upload_expires_at", sa.DateTime(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(),
            server_default=sa.text("now()"),
            nullable=False,
        ),
        sa.Column("confirmed_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("blob_name"),
    )
    op.create_index(
        op.f("ix_progress_photos_user_id"), "progress_photos", ["user_id"], unique=False
    )
    op.create_index(
        "ix_progress_photos_user_captured_at",
        "progress_photos",
        ["user_id", "captured_at"],
        unique=False,
    )
    op.create_index(
        "ix_progress_photos_user_created_at",
        "progress_photos",
        ["user_id", "created_at"],
        unique=False,
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_index("ix_progress_photos_user_created_at", table_name="progress_photos")
    op.drop_index("ix_progress_photos_user_captured_at", table_name="progress_photos")
    op.drop_index(op.f("ix_progress_photos_user_id"), table_name="progress_photos")
    op.drop_table("progress_photos")
