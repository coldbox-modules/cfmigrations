# cfmigrations

## Keep track and run your database migrations with CFML.

### Overview

Database migrations are a way of providing version control for your application's database.  Changes to database schema are kept in timestamped files that are ran in order `up` and `down`.In the `up` function, you describe the changes to apply your migration.  In the `down` function, you describe the changes to undo your migration.

Here's a simple example of that using simple `queryExecute`:

```cfc
component {

    function up() {
        queryExecute( "
            CREATE TABLE `users` (
                `id` INT UNSIGNED AUTO_INCREMENT,
                `email` VARCHAR(255) NOT NULL,
                `password` VARCHAR(255) NOT NULL
            )
        " );
    }

    function down() {
        queryExecute( "
            DROP TABLE `users`
        " );
    }

}
```

The name of this file could be something like `2017_09_03_043150_create_users_table.cfc`.  The first 17 characters of this file represent the timestamp of the migration and need to be in this format: `YYYY_MM_DD_HHMISS`.  The reason for this is so `cfmigrations` can run the migrations in the correct order.  You may have migrations that add columns to a table, so you need to make sure the table exists first.  In this case, just make sure the timestamp for adding the new column comes after the timestamp for creating the table, like so:

```
2017_09_03_043150_create_users_table.cfc
2017_10_03_010406_add_is_subscribed_column.cfc
```

An easy way to generate these files is to use `commandbox-migrations` and the `migrate create` command.


### Installation and Uninstallation

In order to track which migrations have been ran, `cfmigrations` needs to install a table in your database called `cfmigrations`.  You can do this by calling the `install()` method or by running the `migrate install` command from `commandbox-migrations`.

If you find a need to, you can uninstall the migrations table by calling the `uninstall()` method or by running `migrate uninstall` from `commandbox-migrations`.  Running this method will rollback all ran migrations before dropping the `cfmigrations` table.


### Migration Files

A migration file is a component with two methods `up` and `down`.  The function `up` should define how to apply the migration.  The function `down` should define how to undo the change down in `up`.  The `up` and `down` functions are passed an instance of `SchemaBuilder@qb` as the only argument.  To learn more about the functionality and benefits of `SchemaBuilder` and `qb`, please [read the documentation here.](https://elpete.gitbooks.io/qb/content/schema/)  In brief, `qb` and `SchemaBuilder` offers a fluent, expressive syntax that can be compiled to many different database grammars, providing both readability and flexibility.

Here's the same example as above using qb's `SchemaBuilder`:

```cfc
component {

    function up( SchemaBuilder schema ) {
    	schema.create( "users", function( Blueprint table ) {
	    table.increments( "id" );
	    table.string( "email" );
	    table.string( "password" );
	} );
    }

    function down( SchemaBuilder schema ) {
        schema.drop( "users" );
    }

}
```

Migration files need to follow a specific naming convention — `YYYY_MM_DD_HHMISS_[describe_your_changes_here].cfc`.  This is how `cfmigrations` knows in what order to run your migrations.  Generating these files is made easier with the `migrate create` command from `commandbox-migrations`.

In addition to schema changes, you can seed your database with data.  This is especially useful when adding new columns and needing to seed the new columns with the correct data.

There is no limit to what you can do in a migration.  It is recommended that you separate changes to different tables to separate migration files to keep things readable.


### Running Migrations

There are a few methods for running migrations.  (Each of these methods has a related command in `commandbox-migrations`.)

#### `runNextMigration`

Run the next available migration in the desired direction.

|    Name   |   Type   | Required |     Default     |                                    Description                                    |
|-----------|----------|----------|-----------------|-----------------------------------------------------------------------------------|
| direction | String   | `true`   |                 | The direction in which to look for the next available migration — `up` or `down`. |
| callback  | function | `false`  | `function() {}` | A callback to run after running the migration.                                    |

#### `runAllMigrations`

Run all available migrations in the desired direction.

|    Name   |   Type   | Required |     Default     |                     Description                      |
|-----------|----------|----------|-----------------|------------------------------------------------------|
| direction | String   | `true`   |                 | The direction for which to run the available migrations — `up` or `down`. |
| callback  | function | `false`  | `function() {}` | A callback to run after running each migration.       |








