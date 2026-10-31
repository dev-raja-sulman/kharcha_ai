"""create saving_goals and saving_contributions tables

Revision ID: f92a104c8321
Revises: d71a823f4b50
Create Date: 2026-10-31 11:15:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f92a104c8321'
down_revision: Union[str, Sequence[str], None] = 'd71a823f4b50'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create saving_goals table
    op.create_table(
        'saving_goals',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(length=150), nullable=False),
        sa.Column('description', sa.String(length=500), nullable=True),
        sa.Column('target_amount', sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column('current_amount', sa.Numeric(precision=12, scale=2), nullable=False, server_default='0.00'),
        sa.Column('start_date', sa.Date(), nullable=False),
        sa.Column('target_date', sa.Date(), nullable=False),
        sa.Column('status', sa.String(length=20), nullable=False, server_default='in_progress'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint('target_amount > 0', name='check_positive_target_amount'),
        sa.CheckConstraint('current_amount >= 0', name='check_non_negative_current_amount'),
        sa.CheckConstraint("status IN ('in_progress', 'completed', 'cancelled')", name='check_valid_goal_status'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_saving_goals_id'), 'saving_goals', ['id'], unique=False)
    op.create_index(op.f('ix_saving_goals_user_id'), 'saving_goals', ['user_id'], unique=False)
    op.create_index('ix_saving_goals_user_status', 'saving_goals', ['user_id', 'status'], unique=False)
    op.create_index('ix_saving_goals_user_target_date', 'saving_goals', ['user_id', 'target_date'], unique=False)

    # 2. Create saving_contributions table
    op.create_table(
        'saving_contributions',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('goal_id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('amount', sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column('contribution_date', sa.Date(), nullable=False),
        sa.Column('notes', sa.String(length=255), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint('amount > 0', name='check_positive_contribution_amount'),
        sa.ForeignKeyConstraint(['goal_id'], ['saving_goals.id'], ondelete='CASCADE'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_saving_contributions_id'), 'saving_contributions', ['id'], unique=False)
    op.create_index(op.f('ix_saving_contributions_goal_id'), 'saving_contributions', ['goal_id'], unique=False)
    op.create_index(op.f('ix_saving_contributions_user_id'), 'saving_contributions', ['user_id'], unique=False)
    op.create_index(op.f('ix_saving_contributions_contribution_date'), 'saving_contributions', ['contribution_date'], unique=False)
    op.create_index('ix_contributions_goal_date', 'saving_contributions', ['goal_id', 'contribution_date'], unique=False)
    op.create_index('ix_contributions_user_date', 'saving_contributions', ['user_id', 'contribution_date'], unique=False)


def downgrade() -> None:
    op.drop_index('ix_contributions_user_date', table_name='saving_contributions')
    op.drop_index('ix_contributions_goal_date', table_name='saving_contributions')
    op.drop_index(op.f('ix_saving_contributions_contribution_date'), table_name='saving_contributions')
    op.drop_index(op.f('ix_saving_contributions_user_id'), table_name='saving_contributions')
    op.drop_index(op.f('ix_saving_contributions_goal_id'), table_name='saving_contributions')
    op.drop_index(op.f('ix_saving_contributions_id'), table_name='saving_contributions')
    op.drop_table('saving_contributions')

    op.drop_index('ix_saving_goals_user_target_date', table_name='saving_goals')
    op.drop_index('ix_saving_goals_user_status', table_name='saving_goals')
    op.drop_index(op.f('ix_saving_goals_user_id'), table_name='saving_goals')
    op.drop_index(op.f('ix_saving_goals_id'), table_name='saving_goals')
    op.drop_table('saving_goals')
