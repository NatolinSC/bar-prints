# Bar Prints

Till for the club bar: student accounts in "Prints", top-ups, drinks, rankings and levels.

- Front end: `index.html` + `config.js`, served by GitHub Pages.
- Data and sign-in: Supabase (schema in `supabase/schema.sql`).

## Accounts

Only emails listed in the `staff` table can use the till:

```sql
insert into public.staff (email, role) values ('bar@example.com', 'bar'), ('admin@example.com', 'admin');
```

- `bar`: serve drinks, top up, manage students.
- `admin`: everything, plus settings and deleting example accounts.

Create the matching users in Supabase under Authentication -> Users -> Add user, and turn off "Allow new users to sign up".
