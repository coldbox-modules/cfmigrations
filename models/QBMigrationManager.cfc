component accessors="true" {

    property name="wirebox" inject="wirebox";
    property name="mockData" inject="MockData@mockdatacfc";
    property name="defaultGrammar" default="AutoDiscover@qb";
    property name="datasource";
    property name="migrationsTable" default="cfmigrations";
    property name="schema";
    property name="useTransactions" default="true";

    public QBMigrationManager function init() {
        for ( var key in arguments ) {
            if ( !isNull( arguments[ key ] ) ) {
                variables[ key ] = arguments[ key ];
            }
        }
        return this;
    }

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

        var schema = wirebox.getInstance( "SchemaBuilder@qb" ).setGrammar( wirebox.getInstance( defaultGrammar ) );

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
        var schema = wirebox.getInstance( "SchemaBuilder@qb" ).setGrammar( wirebox.getInstance( defaultGrammar ) );
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
            .map( function( row ) {
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
        function preProcessHook = variables.noop
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

        var schema = wirebox
            .getInstance( "SchemaBuilder@qb" )
            .setGrammar( wirebox.getInstance( defaultGrammar ) )
            .setDefaultOptions( { datasource: getDatasource() } );

        var query = wirebox
            .getInstance( "QueryBuilder@qb" )
            .setGrammar( wirebox.getInstance( defaultGrammar ) )
            .setDefaultOptions( { datasource: getDatasource() } );

        preProcessHook( migrationStruct );

        $transactioned( function() {
            invoke( migration, direction, [ schema, query ] );
            logMigration( direction, migrationStruct.componentName );
        } );

        postProcessHook( migrationStruct );
    }

    /**
     * Determines whether the migration table is installed
     */
    public boolean function isMigrationTableInstalled() {
        var schema = wirebox.getInstance( "SchemaBuilder@qb" ).setGrammar( wirebox.getInstance( defaultGrammar ) );

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
        function preProcessHook = variables.noop
    ) {
        arguments.preProcessHook( invocationPath );
        var seeder = wirebox.getInstance( arguments.invocationPath );
        
        var query = wirebox
            .getInstance( "QueryBuilder@qb" )
            .setGrammar( wirebox.getInstance( defaultGrammar ) )
            .setDefaultOptions( { datasource: getDatasource() } );
        
        $transactioned( function() {
            invoke( seeder, "run", [ query, variables.mockData ] );
        } );
        arguments.postProcessHook( invocationPath );
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

}
