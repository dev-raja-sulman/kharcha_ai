"""add multi-currency support

Revision ID: b82e140d3a51
Revises: a73b291e0412
Create Date: 2026-10-31 12:45:00.000000

"""
from datetime import date, datetime, timezone
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b82e140d3a51'
down_revision: Union[str, Sequence[str], None] = 'a73b291e0412'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# Baseline verified exchange rates (relative to PKR as base 1.0)
BASELINE_RATES = [
    ("USD", "PKR", 278.50),
    ("PKR", "USD", 0.003591),
    ("EUR", "PKR", 302.20),
    ("PKR", "EUR", 0.003309),
    ("GBP", "PKR", 355.80),
    ("PKR", "GBP", 0.002811),
    ("AED", "PKR", 75.80),
    ("PKR", "AED", 0.013193),
    ("SAR", "PKR", 74.20),
    ("PKR", "SAR", 0.013477),
    ("INR", "PKR", 3.32),
    ("PKR", "INR", 0.301205),
    ("CAD", "PKR", 202.50),
    ("PKR", "CAD", 0.004938),
    ("AUD", "PKR", 181.40),
    ("PKR", "AUD", 0.005513),
]


def upgrade() -> None:
    # 1. Add preferred_currency to users table
    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.add_column(
            sa.Column('preferred_currency', sa.String(length=10), nullable=False, server_default='PKR')
        )

    # 2. Add currency to expenses table
    with op.batch_alter_table('expenses', schema=None) as batch_op:
        batch_op.add_column(
            sa.Column('currency', sa.String(length=10), nullable=False, server_default='PKR')
        )

    # 3. Add currency to budgets table
    with op.batch_alter_table('budgets', schema=None) as batch_op:
        batch_op.add_column(
            sa.Column('currency', sa.String(length=10), nullable=False, server_default='PKR')
        )

    # 4. Add currency to recurring_expenses table
    with op.batch_alter_table('recurring_expenses', schema=None) as batch_op:
        batch_op.add_column(
            sa.Column('currency', sa.String(length=10), nullable=False, server_default='PKR')
        )

    # 5. Add currency to bills table
    with op.batch_alter_table('bills', schema=None) as batch_op:
        batch_op.add_column(
            sa.Column('currency', sa.String(length=10), nullable=False, server_default='PKR')
        )

    # 6. Add currency to saving_goals table
    with op.batch_alter_table('saving_goals', schema=None) as batch_op:
        batch_op.add_column(
            sa.Column('currency', sa.String(length=10), nullable=False, server_default='PKR')
        )

    # 7. Create exchange_rates table
    exchange_rates_table = op.create_table(
        'exchange_rates',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('from_currency', sa.String(length=10), nullable=False),
        sa.Column('to_currency', sa.String(length=10), nullable=False),
        sa.Column('rate', sa.Numeric(precision=16, scale=6), nullable=False),
        sa.Column('effective_date', sa.Date(), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_exchange_rates_id'), 'exchange_rates', ['id'], unique=False)
    op.create_index(
        'ix_exchange_rates_pair_date',
        'exchange_rates',
        ['from_currency', 'to_currency', 'effective_date'],
        unique=False
    )

    # 8. Seed baseline exchange rates
    today = date.today()
    now = datetime.now(timezone.utc)
    seed_records = [
        {
            "from_currency": from_c,
            "to_currency": to_c,
            "rate": rate,
            "effective_date": today,
            "created_at": now
        }
        for from_c, to_c, rate in BASELINE_RATES
    ]
    op.bulk_insert(exchange_rates_table, seed_records)


def downgrade() -> None:
    op.drop_index('ix_exchange_rates_pair_date', table_name='exchange_rates')
    op.drop_index(op.f('ix_exchange_rates_id'), table_name='exchange_rates')
    op.drop_table('exchange_rates')

    with op.batch_alter_table('saving_goals', schema=None) as batch_op:
        batch_op.drop_column('currency')

    with op.batch_alter_table('bills', schema=None) as batch_op:
        batch_op.drop_column('currency')

    with op.batch_alter_table('recurring_expenses', schema=None) as batch_op:
        batch_op.drop_column('currency')

    with op.batch_alter_table('budgets', schema=None) as batch_op:
        batch_op.drop_column('currency')

    with op.batch_alter_table('expenses', schema=None) as batch_op:
        batch_op.drop_column('currency')

    with op.batch_alter_table('users', schema=None) as batch_op:
        batch_op.drop_column('preferred_currency')
