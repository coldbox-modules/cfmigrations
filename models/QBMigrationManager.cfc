/**
 * Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
 * www.ortussolutions.com
 * ---
 * This class is the default implementation of the IMigrationManager interface, using QueryBuilder to manage migrations and seeders in a database.
 * It provides methods for installing, uninstalling, resetting, and running migrations and seeders.
 * It also provides methods for checking the status of migrations and seeders, and for logging migrations as completed.
 * It uses WireBox for dependency injection and MockData for seeding data.
 */
component accessors="true" {

    /**
     * --------------------------------------------------------------------------
     * DI
     * --------------------------------------------------------------------------
     */

    property name="wirebox" inject="wirebox";
    property name="mockData" inject="MockData@cbMockData";
    property name="defaultGrammar" default="AutoDiscover@qb";
    property name="datasource";
    property name="migrationsTable" default="cbmigrations";
    property name="schema" default="";
    property name="useTransactions" default="true";

    /**
     * --------------------------------------------------------------------------
     * Constructor
     * --------------------------------------------------------------------------
     */
    public QBMigrationManager function init() {
        for ( var key in arguments ) {
            if ( !isNull( arguments[ key ] ) ) {
                variables[ key ] = arguments[ key ];
            }
        }
        return this;
    }

    /**
     * Determines whether the migration manager is ready for operation
     */
    boolean function isReady() {
        return isMigrationTableInstalled();
    }

    /**
     * Performs the necessary routines to setup the migration manager for operation
     */
    function install() {
        if ( isMigrationTableInstalled() ) {
            return;
        }

        var schema = newSchemaBuilder();

        // v6 renamed the default migrations table from `cfmigrations` to `cbmigrations`.
        // Carry forward existing migration history instead of starting fresh.
        if ( schema.hasTable( "cfmigrations", getSchema(), { datasource: getDatasource() } ) ) {
            schema.rename( "cfmigrations", getMigrationsTable(), { datasource: getDatasource() } );
            return;
        }

        schema.create(
            getMigrationsTable(),
            function( table ) {
                table.string( "name", 190 ).primaryKey();
                table.datetime( "migration_ran" );
            },
            { datasource: getDatasource() }
        );
    }

    /**
     * Uninstalls the migrations schema
     */
    public void function uninstall() {
        if ( !isMigrationTableInstalled() ) {
            return;
        }

        queryExecute( "DROP TABLE #getMigrationsTable()#", {}, { datasource: getDatasource() } );
    }

    /**
     * Resets the database to an empty state
     */
    public void function reset() {
        var schema = newSchemaBuilder();
        schema.dropAllObjects( options = { datasource: getDatasource() }, schema = getSchema() );
    }

    /**
     * Finds all processed migrations
     */
    array function findProcessed() {
        return wirebox
            .getInstance( "QueryBuilder@qb" )
            .setGrammar( wirebox.getInstance( defaultGrammar ) )
            .from( getMigrationsTable() )
            .setReturnFormat( "array" )
            .get( [ "name" ], { "datasource": getDatasource() } )
            .map( ( row ) => {
                return row.name;
            } );
    }


    /**
     * Determines whether a migration has been run
     *
     * @componentName The component to inspect
     */
    boolean function isMigrationRan( componentName ) {
        var processed = findProcessed();
        return processed.contains( componentName );
    }

    /**
     * Logs a migration as completed
     *
     * @direction  Whether to log it as up or down
     * @componentName The component name to log
     */
    public void function logMigration( direction, componentName ) {
        if ( direction == "up" ) {
            queryExecute(
                "INSERT INTO #getMigrationsTable()# VALUES ( :name, :time )",
                { name: componentName, time: { value: now(), cfsqltype: "CF_SQL_TIMESTAMP" } },
                { datasource: getDatasource() }
            );
        } else {
            queryExecute(
                "DELETE FROM #getMigrationsTable()# WHERE name = :name",
                { name: componentName },
                { datasource: getDatasource() }
            );
        }
    }


    /**
     * Runs a single migration
     *
     * @direction The direction for which to run the available migrations — `up` or `down`.
     * @migrationStruct A struct containing the meta of the migration to be run
     * @postProcessHook  A callback to run after running each migration. Defaults to an empty function.
     * @preProcessHook  A callback to run before running each migration. Defaults to an empty function.
     */
    public void function runMigration(
        required string direction,
        required struct migrationStruct,
        function postProcessHook = variables.noop,
        function preProcessHook = variables.noop,
        boolean pretend = false
    ) {
        install();

        var migrationRan = isMigrationRan( migrationStruct.componentName );

        if ( migrationRan && direction == "up" ) {
            throw( "Cannot run a migration that has already been ran." );
        }

        if ( !migrationRan && direction == "down" ) {
            throw( "Cannot rollback a migration if it hasn't been ran yet." );
        }

        var migration = wirebox.getInstance( migrationStruct.componentPath );

        var schema = newSchemaBuilder();

        var query = wirebox
            .getInstance( "QueryBuilder@qb" )
            .setGrammar( wirebox.getInstance( defaultGrammar ) )
            .setDefaultOptions( { datasource: getDatasource() } )

        if ( arguments.pretend ) {
            schema.pretend();
            query.pretend();
        }

        preProcessHook( migrationStruct );

        $transactioned( function() {
            invoke( migration, direction, [ schema, query ] );
            if ( !pretend ) {
                logMigration( direction, migrationStruct.componentName );
            }
        } );

        postProcessHook( migrationStruct, schema, query );
    }

    /**
     * Determines whether the migration table is installed
     */
    public boolean function isMigrationTableInstalled() {
        var schema = newSchemaBuilder();
        return schema.hasTable( getMigrationsTable(), getSchema(), { datasource: getDatasource() } );
    }

    /**
     * Runs a single seed
     *
     * @invocationPath the component invocation path for the seed
     */
    public void function runSeed(
        required string invocationPath,
        function postProcessHook = variables.noop,
        function preProcessHook = variables.noop,
        boolean pretend = false
    ) {
        arguments.preProcessHook( invocationPath );
        var seeder = wirebox.getInstance( arguments.invocationPath );

        var query = wirebox
            .getInstance( "QueryBuilder@qb" )
            .setGrammar( wirebox.getInstance( defaultGrammar ) )
            .setDefaultOptions( { datasource: getDatasource() } );

        if ( arguments.pretend ) {
            query.pretend();
        }

        $transactioned( function() {
            invoke( seeder, "run", [ query, variables.mockData ] );
        } );
        arguments.postProcessHook( invocationPath, query );
    }


    /**
     * Transactional wrapper if `useTransactions` is on
     *
     * @target closure  the target to execute from within the transaction
     */
    private function $transactioned( required target ) {
        if ( variables.useTransactions ) {
            transaction action="begin" {
                try {
                    arguments.target();
                } catch ( any e ) {
                    transaction action="rollback";
                    rethrow;
                }
            }
        } else {
            arguments.target();
        }
    }

    private void function noop() {
        return; // intentionally does nothing
    }

    private SchemaBuilder function newSchemaBuilder() {
        return variables.wirebox
            .getInstance( "SchemaBuilder@qb" )
            .setGrammar( variables.wirebox.getInstance( getDefaultGrammar() ) )
            .setDefaultSchema( getSchema() )
            .setDefaultOptions( { datasource: getDatasource() } );
    }

}
