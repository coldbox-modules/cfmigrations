component singleton accessors="true" {

	property name="wirebox" inject="wirebox";
	property name="migrationsDirectory" default="/resources/database/migrations";
	property name="datasource";
	property name="defaultGrammar"  default="AutoDiscover@qb";
	property name="schema"          default="";
	property name="migrationsTable" default="cfmigrations";

	public MigrationService function up(
		boolean once = false,
		postProcessHook,
		preProcessHook
	) {
		arguments.direction = "up";
		if ( arguments.once ) {
			runNextMigration( argumentCollection = arguments );
		} else {
			runAllMigrations( argumentCollection = arguments );
		}
		return this;
	}

	public MigrationService function down(
		boolean once = false,
		postProcessHook,
		preProcessHook
	) {
		arguments.direction = "down";
		if ( arguments.once ) {
			runNextMigration( argumentCollection = arguments );
		} else {
			runAllMigrations( argumentCollection = arguments );
		}
		return this;
	}

	/**
	 * Run the next available migration in the desired direction.
	 *
	 * @direction The direction in which to look for the next available migration — `up` or `down`.
	 * @postProcessHook  A callback to run after running each migration.
	 * @preProcessHook  A callback to run before running each migration.
	 *
	 * @return    The ran migration information struct
	 */
	public struct function runNextMigration(
		required string direction,
		postProcessHook,
		preProcessHook
	) {
		if ( isNull( postProcessHook ) ) {
			postProcessHook = function() {
			};
		}
		if ( isNull( preProcessHook ) ) {
			preProcessHook = function() {
			};
		}

		install();

		var migrations = findAll();

		for ( var migration in migrations ) {
			var canMigrateInDirection = migration[ "canMigrate#direction#" ];
			if ( canMigrateInDirection ) {
				runMigration(
					arguments.direction,
					migration,
					postProcessHook,
					preProcessHook
				);
				return migration;
			}
		}

		return {};
	}

	/**
	 * Run all available migrations in the desired direction.
	 *
	 * @direction The direction for which to run the available migrations — `up` or `down`.
	 * @postProcessHook  A callback to run after running each migration.
	 * @preProcessHook  A callback to run before running each migration.
	 *
	 * @return    void
	 */
	public void function runAllMigrations(
		direction,
		postProcessHook,
		preProcessHook
	) {
		if ( isNull( postProcessHook ) ) {
			postProcessHook = function() {
			};
		}
		if ( isNull( preProcessHook ) ) {
			preProcessHook = function() {
			};
		}

		install();

		var migrations = arrayFilter( findAll(), function( migration ) {
			return direction == "up" ? !migration.migrated : migration.migrated;
		} );

		if ( direction == "down" ) {
			// sort in reversed order to get which migrations can be brought down
			// cannot use arrayReverse since it is Lucee only
			arraySort( migrations, function( a, b ) {
				return dateCompare( b.timestamp, a.timestamp );
			} );
		}

		arrayEach( migrations, function( migration ) {
			runMigration(
				direction,
				migration,
				postProcessHook,
				preProcessHook
			);
		} );
	}

	public array function findAll() {
		var migrationTableInstalled = isMigrationTableInstalled();

		var objectsQuery = directoryList(
			expandPath( migrationsDirectory ),
			false,
			"query"
		);
		var objectsArray = [];
		for ( var row in objectsQuery ) {
			arrayAppend( objectsArray, row );
		}
		var onlyCFCs = arrayFilter( objectsArray, function( object ) {
			return object.type == "File" &&
			right( object.name, 4 ) == ".cfc" &&
			isMigrationFile( object.name );
		} );

		arraySort( onlyCFCs, function( a, b ) {
			return dateCompare( extractTimestampFromFileName( a.name ), extractTimestampFromFileName( b.name ) );
		} );

		var prequisitesInstalled = true;
		var migrations           = arrayMap( onlyCFCs, function( file ) {
			var timestamp     = extractTimestampFromFileName( file.name );
			var componentName = left( file.name, len( file.name ) - 4 );
			var migrationRan  = migrationTableInstalled ? isMigrationRan( componentName ) : false;

			var migration = {
				fileName      : file.name,
				componentName : componentName,
				absolutePath  : file.directory & "/" & file.name,
				componentPath : listChangeDelims(
					migrationsDirectory & "/" & componentName,
					".",
					"/",
					false
				),
				timestamp      : timestamp,
				migrated       : migrationRan,
				canMigrateUp   : !migrationRan && prequisitesInstalled,
				canMigrateDown : migrationRan,
				migratedDate   : ""
			};

			prequisitesInstalled = migrationRan;

			return migration;
		} );

		if ( !migrationTableInstalled && !arrayIsEmpty( migrations ) ) {
			arrayEach( migrations, function( migration ) {
				migration.canMigrateUp   = false;
				migration.canMigrateDown = false;
			} );

			// sort in the correct order
			arraySort( migrations, function( a, b ) {
				return dateCompare( a.timestamp, b.timestamp );
			} );

			return migrations;
		}

		// sort in reversed order to get which migrations can be brought down
		arraySort( migrations, function( a, b ) {
			return dateCompare( b.timestamp, a.timestamp );
		} );

		var laterMigrationsNotInstalled = true;
		arrayEach( migrations, function( migration ) {
			migration.canMigrateDown    = migration.migrated && laterMigrationsNotInstalled;
			laterMigrationsNotInstalled = !migration.migrated;
		} );

		// sort in the correct order
		arraySort( migrations, function( a, b ) {
			return dateCompare( a.timestamp, b.timestamp );
		} );

		return migrations;
	}

	public boolean function hasMigrationsToRun( direction ) {
		return !arrayIsEmpty(
			arrayFilter( findAll(), function( migration ) {
				return direction == "up" ? !migration.migrated : migration.migrated;
			} )
		);
	}

	public void function install( runAll = false ) {
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

		if ( runAll ) {
			runAllMigrations( "up" );
		}
	}

	public void function uninstall() {
		if ( !isMigrationTableInstalled() ) {
			return;
		}

		runAllMigrations( "down" );

		queryExecute(
			"DROP TABLE #getMigrationsTable()#",
			{},
			{ datasource : getDatasource() }
		);
	}

	public void function reset() {
		var schema = wirebox.getInstance( "SchemaBuilder@qb" ).setGrammar( wirebox.getInstance( defaultGrammar ) );
		schema.dropAllObjects( options = { datasource : getDatasource() }, schema = getSchema() );
	}

	public boolean function isMigrationTableInstalled() {
		var schema = wirebox.getInstance( "SchemaBuilder@qb" ).setGrammar( wirebox.getInstance( defaultGrammar ) );

		return schema.hasTable(
			getMigrationsTable(),
			getSchema(),
			{ datasource : getDatasource() }
		);
	}

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
		transaction action="begin" {
			try {
				invoke(
					migration,
					direction,
					[ schema, query ]
				);
				logMigration( direction, migrationStruct.componentName );
			} catch ( any e ) {
				transaction action="rollback";
				rethrow;
			}
		}
		postProcessHook( migrationStruct );
	}

	private boolean function isMigrationRan( componentName ) {
		var migrations = queryExecute(
			"
                SELECT name
                FROM #getMigrationsTable()#
            ",
			{},
			{ datasource : getDatasource() }
		);

		for ( var migration in migrations ) {
			if ( migration.name == componentName ) {
				return true;
			}
		}
		return false;
	}

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

	private boolean function isMigrationFile( filename ) {
		return isDate(
			replace(
				left( filename, 10 ),
				"_",
				"-",
				"all"
			)
		);
	}

	private any function extractTimestampFromFileName( fileName ) {
		var timestampString = left( fileName, 17 );
		var timestampParts  = listToArray( timestampString, "_" );
		return createDateTime(
			timestampParts[ 1 ],
			timestampParts[ 2 ],
			timestampParts[ 3 ],
			mid( timestampParts[ 4 ], 1, 2 ),
			mid( timestampParts[ 4 ], 3, 2 ),
			mid( timestampParts[ 4 ], 5, 2 )
		);
	}

}
