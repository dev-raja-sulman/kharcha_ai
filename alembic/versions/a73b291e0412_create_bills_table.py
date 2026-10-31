"""create bills table

Revision ID: a73b291e0412
Revises: f92a104c8321
Create Date: 2026-10-31 11:30:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a73b291e0412'
down_revision: Union[str, Sequence[str], None] = 'f92a104c8321'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'bills',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('title', sa.String(length=150), nullable=False),
        sa.Column('category', sa.String(length=50), nullable=False, server_default='Other'),
        sa.Column('amount', sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column('due_date', sa.Date(), nullable=False),
        sa.Column('status', sa.String(length=20), nullable=False, server_default='unpaid'),
        sa.Column('frequency', sa.String(length=20), nullable=False, server_default='one_time'),
        sa.Column('reminder_enabled', sa.Boolean(), nullable=False, server_default=sa.text('1')),
        sa.Column('paid_date', sa.Date(), nullable=True),
        sa.Column('linked_expense_id', sa.Integer(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint('amount > 0', name='check_positive_bill_amount'),
        sa.CheckConstraint("status IN ('unpaid', 'paid', 'overdue')", name='check_valid_bill_status'),
        sa.CheckConstraint("frequency IN ('one_time', 'monthly', 'quarterly', 'yearly')", name='check_valid_bill_frequency'),
        sa.ForeignKeyConstraint(['linked_expense_id'], ['expenses.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_bills_id'), 'bills', ['id'], unique=False)
    op.create_index(op.f('ix_bills_user_id'), 'bills', ['user_id'], unique=False)
    op.create_index(op.f('ix_bills_status'), 'bills', ['status'], unique=False)
    op.create_index(op.f('ix_bills_due_date'), 'bills', ['due_date'], unique=False)
    op.create_index(op.f('ix_bills_linked_expense_id'), 'bills', ['linked_expense_id'], unique=False)
    op.create_index('ix_bills_user_status', 'bills', ['user_id', 'status'], unique=False)
    op.create_index('ix_bills_user_due_date', 'bills', ['user_id', 'due_date'], unique=False)


def downgrade() -> None:
    op.drop_index('ix_bills_user_due_date', table_name='bills')
    op.drop_index('ix_bills_user_status', table_name='bills')
    op.drop_index(op.f('ix_bills_linked_expense_id'), table_name='bills')
    op.drop_index(op.f('ix_bills_due_date'), table_name='bills')
    op.drop_index(op.f('ix_bills_status'), table_name='bills')
    op.drop_index(op.f('ix_bills_user_id'), table_name='bills')
    op.drop_index(op.f('ix_bills_id'), table_name='bills')
    op.drop_table('bills')
