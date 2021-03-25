component accessors="true" {

	property name="wirebox" inject="wirebox";
	property name="defaultGrammar" default="AutoDiscover@qb";
	property name="datasource";
	property name="migrationsTable" default="cfmigrations";
	property name="schema";
	property name="useTransactions" default="true";

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
			{ datasource : getDatasource() }
		);
	}

	/**
	 * Uninstalls the migrations schema
	 */
	public void function uninstall() {
		if ( !isMigrationTableInstalled() ) {
			return;
		}

		queryExecute(
			"DROP TABLE #getMigrationsTable()#",
			{},
			{ datasource : getDatasource() }
		);
	}

	/**
	 * Resets the database to an empty state
	 */
	public void function reset() {
		var schema = wirebox.getInstance( "SchemaBuilder@qb" ).setGrammar( wirebox.getInstance( defaultGrammar ) );
		schema.dropAllObjects( options = { datasource : getDatasource() }, schema = getSchema() );
	}

	/**
	 * Finds all processed migrations
	 */
	array function findProcessed() {
		return wirebox.getInstance( "QueryBuilder@qb" )
				.from( getMigrationsTable() )
				.setReturnFormat( "array" )
				.get( [ "name" ], { "datasource" : getDatasource()  } )
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
	private void function logMigration( direction, componentName ) {
		if ( direction == "up" ) {
			queryExecute(
				"INSERT INTO #getMigrationsTable()# VALUES ( :name, :time )",
				{
					name : componentName,
					time : {
						value     : now(),
						cfsqltype : "CF_SQL_TIMESTAMP"
					}
				},
				{ datasource : getDatasource() }
			);
		} else {
			queryExecute(
				"DELETE FROM #getMigrationsTable()# WHERE name = :name",
				{ name : componentName },
				{ datasource : getDatasource() }
			);
		}
	}


	/**
	 * Runs a single migration
	 * 
	 * @direction The direction for which to run the available migrations — `up` or `down`.
	 * @migrationStruct A struct containing the meta of the migration to be run
	 * @postProcessHook  A callback to run after running each migration.
	 * @preProcessHook  A callback to run before running each migration.
	 */
	public void function runMigration(
		direction,
		migrationStruct,
		postProcessHook,
		preProcessHook
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

		var schema = wirebox.getInstance( "SchemaBuilder@qb" ).setGrammar( wirebox.getInstance( defaultGrammar ) );

		var query = wirebox.getInstance( "QueryBuilder@qb" ).setGrammar( wirebox.getInstance( defaultGrammar ) );

		preProcessHook( migrationStruct );

		$transactioned( function() {
			invoke(
				migration,
				direction,
				[ schema, query ]
			);
			logMigration( direction, migrationStruct.componentName );
		} );

		postProcessHook( migrationStruct );
	}

	/**
	 * Determines whether the migration table is installed
	 */
	public boolean function isMigrationTableInstalled() {
		var schema = wirebox.getInstance( "SchemaBuilder@qb" ).setGrammar( wirebox.getInstance( defaultGrammar ) );

		return schema.hasTable(
			getMigrationsTable(),
			getSchema(),
			{ datasource : getDatasource() }
		);
	}

	/**
	 * Runs a single seed
	 *
	 * @invocationPath the component invocation path for the seed
	 */
	public void function runSeed(
		required string invocationPath
	) {
		
		var seeder = wirebox.getInstance( arguments.invocationPath );

		var schema = wirebox.getInstance( "SchemaBuilder@qb" ).setGrammar( wirebox.getInstance( defaultGrammar ) );

		var query = wirebox.getInstance( "QueryBuilder@qb" ).setGrammar( wirebox.getInstance( defaultGrammar ) );

		var mockData = wirebox.getInstance( "MockData@mockdatacfc" );

		$transactioned( function() {
			invoke(
				seeder,
				"run",
				[ schema, query, mockData ]
			);
		} );

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

}
