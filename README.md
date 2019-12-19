# cfmigrations

## Keep track and run your database migrations with CFML.

### Overview

Database migrations are a way of providing version control for your application's database. Changes to database schema are kept in timestamped files that are ran in order `up` and `down`.In the `up` function, you describe the changes to apply your migration. In the `down` function, you describe the changes to undo your migration.

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

The name of this file could be something like `2017_09_03_043150_create_users_table.cfc`. The first 17 characters of this file represent the timestamp of the migration and need to be in this format: `YYYY_MM_DD_HHMISS`. The reason for this is so `cfmigrations` can run the migrations in the correct order. You may have migrations that add columns to a table, so you need to make sure the table exists first. In this case, just make sure the timestamp for adding the new column comes after the timestamp for creating the table, like so:

```
2017_09_03_043150_create_users_table.cfc
2017_10_03_010406_add_is_subscribed_column.cfc
```

An easy way to generate these files is to use `commandbox-migrations` and the `migrate create` command.

### Installation and Uninstallation

In order to track which migrations have been ran, `cfmigrations` needs to install a table in your database called `cfmigrations`. You can do this by calling the `install()` method or by running the `migrate install` command from `commandbox-migrations`.

If you find a need to, you can uninstall the migrations table by calling the `uninstall()` method or by running `migrate uninstall` from `commandbox-migrations`. Running this method will rollback all ran migrations before dropping the `cfmigrations` table.

### Setting Schema

It's important to set the `schema` attribute for `cfmigrations`.  Without it, `cfmigrations` can't tell the difference
between a migration table installed in the schema you want and any other schema on the same database.  You can
set the schema by calling the `setSchema( string schema )` method.

### Migration Files

A migration file is a component with two methods `up` and `down`. The function `up` should define how to apply the migration. The function `down` should define how to undo the change down in `up`. The `up` and `down` functions are passed an instance of `SchemaBuilder@qb` and `QueryBuilder@qb` as arguments. To learn more about the functionality and benefits of `SchemaBuilder`, `QueryBuilder`, and `qb`, please [read the QB documentation here](https://qb.ortusbooks.com/). In brief, `qb` offers a fluent, expressive syntax that can be compiled to many different database grammars, providing both readability and flexibility.

Here's the same example as above using qb's `SchemaBuilder`:

```cfc
component {

    function up( SchemaBuilder schema, QueryBuilder query ) {
    	schema.create( "users", function( Blueprint table ) {
	    table.increments( "id" );
	    table.string( "email" );
	    table.string( "password" );
	} );
    }

    function down( SchemaBuilder schema, QueryBuilder query ) {
        schema.drop( "users" );
    }

}
```

Migration files need to follow a specific naming convention — `YYYY_MM_DD_HHMISS_[describe_your_changes_here].cfc`. This is how `cfmigrations` knows in what order to run your migrations. Generating these files is made easier with the `migrate create` command from `commandbox-migrations`.

In addition to schema changes, you can seed your database with data. This is especially useful when adding new columns and needing to seed the new columns with the correct data.

There is no limit to what you can do in a migration. It is recommended that you separate changes to different tables to separate migration files to keep things readable.

### Running Migrations

There are a few methods for working with migrations. (Each of these methods has a related command in `commandbox-migrations`.)

These methods can be run by injecting `MigrationService@cfmigrations` - for example: `getInstance( "MigrationService@cfmigrations" ).runAllMigrations( "up" )` will run all migrations.

#### `runNextMigration`

Run the next available migration in the desired direction.

| Name      | Type     | Required | Default         | Description                                                                       |
| --------- | -------- | -------- | --------------- | --------------------------------------------------------------------------------- |
| direction | String   | `true`   |                 | The direction in which to look for the next available migration — `up` or `down`. |
| postProcessHook  | function | `false`  | `function() {}` | A callback to run *after* running the migration.                                    |
| preProcessHook   | function | `false`  | `function() {}` | A callback to run *before* running the migration.                                    |

#### `runAllMigrations`

Run all available migrations in the desired direction.

| Name      | Type     | Required | Default         | Description                                                               |
| --------- | -------- | -------- | --------------- | ------------------------------------------------------------------------- |
| direction | String   | `true`   |                 | The direction for which to run the available migrations — `up` or `down`. |
| postProcessHook  | function | `false`  | `function() {}` | A callback to run *after* running each migration.                                    |
| preProcessHook   | function | `false`  | `function() {}` | A callback to run *before* running each migration.                                    |

#### `reset`

Returns the database to an empty state by dropping all objects.

#### `findAll`

Returns an array of **all** migrations:

```js
[{
	fileName = "2019_12_18_195831_create-users-table.cfc",
	componentName = "2019_12_18_195831_create-users-table",
	absolutePath = "/var/www/html/app/resources/migrations/2019_12_18_195831_create-users-table.cfc",
	componentPath = "/app/resources/migrations/2019_12_18_195831_create-users-table.cfc",
	timestamp = 123455555,
	migrated = false,
	canMigrateUp = true,
	canMigrateDown = false,
	migratedDate = "2019-03-22"
}]
```

#### `hasMigrationsToRun`

Returns `true` if there are available migrations which can be run in the provided order.

| Name      | Type     | Required | Default         | Description                                                               |
| --------- | -------- | -------- | --------------- | ------------------------------------------------------------------------- |
| direction | String   | `true`   |                 | The direction for which to run the available migrations — `up` or `down`. |

### Tips and tricks

#### Default values in MS SQL server

MS SQL server requires some special treatment when removing columns with default values. Even though syntax is almost the same, MS SQL creates a special default constraint like `DF_tablename_columname`. When migrating down, this constraint has to be removed before dropping the column. In other grammars no special named constraint is created.

Example:
```cfc
component {

    function up( schema, query   ) {
        schema.alter( "users", function ( table ) {
            table.addColumn( table.boolean( "hassuperpowers").default(0) );
        });
    }

    function down( schema, query  ) {
        schema.alter( "users", function( table ) {
            table.dropConstraint( "DF_users_hassuperpowers");
            table.dropColumn( "hassuperpowers" ) ;
        } );
    }

}
```


#### Updating database content in a migration file

Sometimes you want to do multiple content updates or inserts in a migration. In this case you can use the QueryBuilder for the updates. When doing your second update you have to reset the Querybuilder object by using the newQuery method.

Example:

```cfc
component {

    function up( SchemaBuilder schema, QueryBuilder query ) {
	query.from('users')
	    .where( "username", "superuser")
	    .update( {"hassuperpowers" = true} )
	query.newQuery().from('users')
	    .where('username','RandomUser')
	    .update( {"hassuperpowers" = false} )
    }

    function down( SchemaBuilder schema, QueryBuilder query ) {
        ......
    }

}
```
