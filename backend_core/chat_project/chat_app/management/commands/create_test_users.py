"""
Management command to create test users for development.
Usage: python manage.py create_test_users
"""
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model

User = get_user_model()


class Command(BaseCommand):
    help = 'Create test users for development and testing'

    def add_arguments(self, parser):
        parser.add_argument(
            '--count',
            type=int,
            default=15,
            help='Number of test users to create (default: 15)',
        )

    def handle(self, *args, **options):
        count = options['count']
        created = 0
        skipped = 0

        # Test user data
        test_users = [
            {
                'username': 'alice',
                'email': 'alice@example.com',
                'password': 'testpass123',
                'first_name': 'Alice',
                'last_name': 'Johnson',
            },
            {
                'username': 'bob',
                'email': 'bob@example.com',
                'password': 'testpass123',
                'first_name': 'Bob',
                'last_name': 'Smith',
            },
            {
                'username': 'charlie',
                'email': 'charlie@example.com',
                'password': 'testpass123',
                'first_name': 'Charlie',
                'last_name': 'Brown',
            },
            {
                'username': 'diana',
                'email': 'diana@example.com',
                'password': 'testpass123',
                'first_name': 'Diana',
                'last_name': 'Wilson',
            },
            {
                'username': 'evan',
                'email': 'evan@example.com',
                'password': 'testpass123',
                'first_name': 'Evan',
                'last_name': 'Davis',
            },
            {
                'username': 'fiona',
                'email': 'fiona@example.com',
                'password': 'testpass123',
                'first_name': 'Fiona',
                'last_name': 'Miller',
            },
            {
                'username': 'george',
                'email': 'george@example.com',
                'password': 'testpass123',
                'first_name': 'George',
                'last_name': 'Taylor',
            },
            {
                'username': 'hannah',
                'email': 'hannah@example.com',
                'password': 'testpass123',
                'first_name': 'Hannah',
                'last_name': 'Anderson',
            },
            {
                'username': 'isaac',
                'email': 'isaac@example.com',
                'password': 'testpass123',
                'first_name': 'Isaac',
                'last_name': 'Thomas',
            },
            {
                'username': 'julia',
                'email': 'julia@example.com',
                'password': 'testpass123',
                'first_name': 'Julia',
                'last_name': 'Jackson',
            },
            {
                'username': 'kevin',
                'email': 'kevin@example.com',
                'password': 'testpass123',
                'first_name': 'Kevin',
                'last_name': 'White',
            },
            {
                'username': 'laura',
                'email': 'laura@example.com',
                'password': 'testpass123',
                'first_name': 'Laura',
                'last_name': 'Harris',
            },
            {
                'username': 'michael',
                'email': 'michael@example.com',
                'password': 'testpass123',
                'first_name': 'Michael',
                'last_name': 'Martin',
            },
            {
                'username': 'nancy',
                'email': 'nancy@example.com',
                'password': 'testpass123',
                'first_name': 'Nancy',
                'last_name': 'Garcia',
            },
            {
                'username': 'oliver',
                'email': 'oliver@example.com',
                'password': 'testpass123',
                'first_name': 'Oliver',
                'last_name': 'Rodriguez',
            },
        ]

        for user_data in test_users[:count]:
            try:
                user = User.objects.get(username=user_data['username'])
                self.stdout.write(
                    self.style.WARNING(
                        f"User '{user_data['username']}' already exists, skipping..."
                    )
                )
                skipped += 1
            except User.DoesNotExist:
                password = user_data.pop('password')
                user = User.objects.create_user(password=password, **user_data)
                self.stdout.write(
                    self.style.SUCCESS(
                        f"✓ Created user: {user.username} ({user.email})"
                    )
                )
                created += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"\n✓ Complete: Created {created} users, skipped {skipped} existing users"
            )
        )
