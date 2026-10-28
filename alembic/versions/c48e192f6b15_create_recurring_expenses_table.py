"""create recurring expenses table and update expenses table

Revision ID: c48e192f6b15
Revises: 85e7b4469633
Create Date: 2026-10-28 18:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'c48e192f6b15'
down_revision: Union[str, Sequence[str], None] = '85e7b4469633'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create recurring_expenses table
    op.create_table(
        'recurring_expenses',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(length=150), nullable=False),
        sa.Column('amount', sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column('category', sa.String(length=50), nullable=False),
        sa.Column('description', sa.String(length=500), nullable=True),
        sa.Column('frequency', sa.String(length=20), nullable=False),
        sa.Column('payment_method', sa.String(length=50), nullable=False, server_default='Cash'),
        sa.Column('start_date', sa.Date(), nullable=False),
        sa.Column('end_date', sa.Date(), nullable=True),
        sa.Column('next_scheduled_date', sa.Date(), nullable=False),
        sa.Column('last_generated_date', sa.Date(), nullable=True),
        sa.Column('status', sa.String(length=20), nullable=False, server_default='active'),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint('amount > 0', name='check_positive_recurring_amount'),
        sa.CheckConstraint("frequency IN ('daily', 'weekly', 'monthly', 'yearly')", name='check_valid_recurring_frequency'),
        sa.CheckConstraint("status IN ('active', 'paused', 'cancelled', 'completed')", name='check_valid_recurring_status'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_recurring_expenses_id'), 'recurring_expenses', ['id'], unique=False)
    op.create_index(op.f('ix_recurring_expenses_user_id'), 'recurring_expenses', ['user_id'], unique=False)
    op.create_index(op.f('ix_recurring_expenses_category'), 'recurring_expenses', ['category'], unique=False)
    op.create_index(op.f('ix_recurring_expenses_frequency'), 'recurring_expenses', ['frequency'], unique=False)
    op.create_index(op.f('ix_recurring_expenses_status'), 'recurring_expenses', ['status'], unique=False)
    op.create_index(op.f('ix_recurring_expenses_next_scheduled_date'), 'recurring_expenses', ['next_scheduled_date'], unique=False)
    op.create_index('ix_recurring_user_status', 'recurring_expenses', ['user_id', 'status'], unique=False)
    op.create_index('ix_recurring_user_next_date', 'recurring_expenses', ['user_id', 'next_scheduled_date'], unique=False)

    # 2. Update expenses table using batch_alter_table for SQLite compatibility
    with op.batch_alter_table('expenses') as batch_op:
        batch_op.add_column(sa.Column('recurring_rule_id', sa.Integer(), nullable=True))
        batch_op.add_column(sa.Column('recurring_occurrence_date', sa.Date(), nullable=True))
        batch_op.create_foreign_key(
            'fk_expenses_recurring_rule_id',
            'recurring_expenses',
            ['recurring_rule_id'],
            ['id'],
            ondelete='SET NULL'
        )
        batch_op.create_index(
            'uq_expenses_recurring_occurrence',
            ['recurring_rule_id', 'recurring_occurrence_date'],
            unique=True
        )


def downgrade() -> None:
    with op.batch_alter_table('expenses') as batch_op:
        batch_op.drop_index('uq_expenses_recurring_occurrence')
        batch_op.drop_constraint('fk_expenses_recurring_rule_id', type_='foreignkey')
        batch_op.drop_column('recurring_occurrence_date')
        batch_op.drop_column('recurring_rule_id')

    op.drop_index('ix_recurring_user_next_date', table_name='recurring_expenses')
    op.drop_index('ix_recurring_user_status', table_name='recurring_expenses')
    op.drop_index(op.f('ix_recurring_expenses_next_scheduled_date'), table_name='recurring_expenses')
    op.drop_index(op.f('ix_recurring_expenses_status'), table_name='recurring_expenses')
    op.drop_index(op.f('ix_recurring_expenses_frequency'), table_name='recurring_expenses')
    op.drop_index(op.f('ix_recurring_expenses_category'), table_name='recurring_expenses')
    op.drop_index(op.f('ix_recurring_expenses_user_id'), table_name='recurring_expenses')
    op.drop_index(op.f('ix_recurring_expenses_id'), table_name='recurring_expenses')
    op.drop_table('recurring_expenses')
