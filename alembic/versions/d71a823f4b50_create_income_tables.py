"""create income_sources and incomes tables

Revision ID: d71a823f4b50
Revises: c48e192f6b15
Create Date: 2026-10-31 11:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd71a823f4b50'
down_revision: Union[str, Sequence[str], None] = 'c48e192f6b15'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Create income_sources table
    op.create_table(
        'income_sources',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=True),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('description', sa.String(length=255), nullable=True),
        sa.Column('is_active', sa.Boolean(), nullable=False, server_default=sa.text('1')),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_income_sources_id'), 'income_sources', ['id'], unique=False)
    op.create_index(op.f('ix_income_sources_user_id'), 'income_sources', ['user_id'], unique=False)
    op.create_index('ix_income_sources_user_active', 'income_sources', ['user_id', 'is_active'], unique=False)

    # 2. Create incomes table
    op.create_table(
        'incomes',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('source_id', sa.Integer(), nullable=True),
        sa.Column('title', sa.String(length=150), nullable=False),
        sa.Column('amount', sa.Numeric(precision=12, scale=2), nullable=False),
        sa.Column('currency', sa.String(length=10), nullable=False, server_default='PKR'),
        sa.Column('income_date', sa.Date(), nullable=False),
        sa.Column('payment_method', sa.String(length=50), nullable=False, server_default='Bank Transfer'),
        sa.Column('description', sa.String(length=500), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint('amount > 0', name='check_positive_income_amount'),
        sa.ForeignKeyConstraint(['source_id'], ['income_sources.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_incomes_id'), 'incomes', ['id'], unique=False)
    op.create_index(op.f('ix_incomes_user_id'), 'incomes', ['user_id'], unique=False)
    op.create_index(op.f('ix_incomes_source_id'), 'incomes', ['source_id'], unique=False)
    op.create_index(op.f('ix_incomes_income_date'), 'incomes', ['income_date'], unique=False)
    op.create_index('ix_incomes_user_date', 'incomes', ['user_id', 'income_date'], unique=False)
    op.create_index('ix_incomes_user_source', 'incomes', ['user_id', 'source_id'], unique=False)


def downgrade() -> None:
    op.drop_index('ix_incomes_user_source', table_name='incomes')
    op.drop_index('ix_incomes_user_date', table_name='incomes')
    op.drop_index(op.f('ix_incomes_income_date'), table_name='incomes')
    op.drop_index(op.f('ix_incomes_source_id'), table_name='incomes')
    op.drop_index(op.f('ix_incomes_user_id'), table_name='incomes')
    op.drop_index(op.f('ix_incomes_id'), table_name='incomes')
    op.drop_table('incomes')

    op.drop_index('ix_income_sources_user_active', table_name='income_sources')
    op.drop_index(op.f('ix_income_sources_user_id'), table_name='income_sources')
    op.drop_index(op.f('ix_income_sources_id'), table_name='income_sources')
    op.drop_table('income_sources')
