"""Create sms responses table

Revision ID: 36ee8081de34
Revises: 8bbb4bdadb96
Create Date: 2021-03-22 01:43:49.408095

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.sql import func

# revision identifiers, used by Alembic.
revision = '36ee8081de34'
down_revision = '8bbb4bdadb96'
branch_labels = None
depends_on = None


def upgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.create_table(
        'sms_responses',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('Description', sa.Text(), nullable=False),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_table(
        'sms_recipients',
        sa.Column('id', sa.Integer(), autoincrement=True, nullable=False),
        sa.Column('Cost', sa.Text(), nullable=False),
        sa.Column('Status Code', sa.Integer(), nullable=True),
        sa.Column('Number', sa.Text(), nullable=False),
        sa.Column('Message ID', sa.Text(), nullable=False),
        sa.Column('Message Parts', sa.Integer(), nullable=True),
        sa.Column('Status', sa.Text(), nullable=False),
        sa.Column('source', sa.Integer(), nullable=True),
        sa.Column('Creation Date', sa.DateTime(), nullable=True, server_default=func.now()),
        sa.ForeignKeyConstraint(('source',), ['sms_responses.id'], onupdate='CASCADE', ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('Message ID')
    )
    op.create_index(op.f('ix_sms_recipients_Creation Date'), 'sms_recipients', ['Creation Date'], unique=False)
    # ### end Alembic commands ###


def downgrade():
    # ### commands auto generated by Alembic - please adjust! ###
    op.drop_index(op.f('ix_sms_recipients_Creation Date'), table_name='sms_recipients')
    op.drop_table('sms_recipients')
    op.drop_table('sms_responses')
    # ### end Alembic commands ###