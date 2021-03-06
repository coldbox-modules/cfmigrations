component singleton accessors="true" {

	property name="wirebox" inject="wirebox";
	property name="migrationsDirectory" default="/resources/database/migrations";
	property name="seedsDirectory" default="/resources/database/seeds";
	property name="manager"   default="cfmigrations.models.QBMigrationManager";
	

	MigrationService function init(){
		structAppend( variables, arguments, true );
		return this;
	}

	function onDIComplete(){
		variables.manager = variables.wirebox.getInstance( variables.manager );

		var omit = [ "wirebox", "migrationsDirectory", "seedsDirectory", "manager" ];

		variables.keyArray()
					.filter( function( key ){
						return isSimpleValue( variables[ key ] ) && !omit.contains( key );
					} )
					.each( function( key ){
						invoke( variables.manager, "set" & key, variables[ key ] );
					} );
		
	}

	public void function install( runAll = false ) {
		variables.manager.install( argumentCollection=arguments );

		if ( runAll ) {
			runAllMigrations( "up" );
		}
	}

	public void function uninstall() {
		if ( !variables.manager.isReady() ) {
			return;
		}

		runAllMigrations( "down" );

		variables.manager.uninstall();
	}

	public void function reset() {
		return variables.manager.reset();
	}

	public MigrationService function up(
		boolean once = false,
		postProcessHook,
		preProcessHook,
		boolean seed = false
	) {
		arguments.direction = "up";
		
		if ( arguments.once ) {
			runNextMigration( argumentCollection = arguments );
		} else {
			runAllMigrations( argumentCollection = arguments );
		}

		if( arguments.seed ){
			this.seed();
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

	public MigrationService function seed(){

		if( !directoryExists( expandPath( variables.seedsDirectory ) ) ) return this;

		var seeds = findSeeds();
		
		seeds.each( function( file ){
			runMigration(
				direction="up",
				migrationStruct = file,
				preProcessHook = function(){},
				postProcessHook = function(){}
			);
		} );

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

	public array function findAll( string directory = variables.migrationsDirectory ) {

		var migrationFiles = directoryList(
				path = expandPath( arguments.directory ),
				recurse = false,
				listInfo = "query",
				filter = "*.cfc",
				sort = "name",
				type = "file"
			)
			.reduce( function( result, row ){ result.append( row );return result; }, [] )
			.filter( function( item ){
				return isMigrationFile( item.name );
			} );


		var processed = variables.manager.findProcessed();

		var prequisitesInstalled = true;
		var managerIsReady = variables.manager.isReady();

		var migrations = migrationFiles.map( function( file ){
			var timestamp     = extractTimestampFromFileName( file.name );
			var componentName = left( file.name, len( file.name ) - 4 );
			var migrationRan  = managerIsReady ? processed.contains( componentName ) : false;

			var migration = {
				fileName      : file.name,
				componentName : componentName,
				absolutePath  : file.directory & "/" & file.name,
				componentPath : listChangeDelims(
					directory & "/" & componentName,
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

		

		if ( !managerIsReady ) {
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
		migrations.sort(
			function( a, b ) {
				return dateCompare( b.timestamp, a.timestamp );
			}
		);

		var laterMigrationsNotInstalled = true;

		migrations.each( 
			function( migration ) {
				migration.canMigrateDown    = migration.migrated && laterMigrationsNotInstalled;
				laterMigrationsNotInstalled = !migration.migrated;
			}
		);

		// resort to timestamp asc
		migrations.sort(
			function( a, b ) {
				return dateCompare( a.timestamp, b.timestamp );
			}
		);

		return migrations;
	}

	public array function findSeeds(){
		return findAll( directory=variables.seedsDirectory );
	}

	public boolean function hasMigrationsToRun( direction ) {
		return !! findAll().filter( 
			function( migration ) {
				return direction == "up" ? !migration.migrated : migration.migrated;
			}
		).len();
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

		preProcessHook( migrationStruct );

		variables.manager.runMigration( argumentCollection=arguments );

		postProcessHook( migrationStruct );
		
	}

	private boolean function isMigrationRan( componentName ) {
		return variables.manager.isMigrationRan( argumentCollection=arguments );
	}

	private void function logMigration( direction, componentName ) {
		variables.manager.logMigration( argumentCollection = arguments );
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
