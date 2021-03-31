component singleton accessors="true" {

    property name="wirebox" inject="wirebox";
    property name="environment" inject="coldbox:setting:environment" default="development";
    property name="manager" default="cfmigrations.models.QBMigrationManager";
    property name="migrationsDirectory" default="/resources/database/migrations";
    property name="seedsDirectory" default="/resources/database/seeds";
    property name="seedEnvironments" default="development";
    property name="managerProperties";


    /**
     * Initializes the Migration Service instance
     *
     * @manager
     * @migrationsDirectory
     * @seedsDirectory
     * @seedEnvironments
     * @properties
     */
    MigrationService function init(
        any manager,
        string migrationsDirectory,
        string seedsDirectory,
        any seedEnvironments,
        struct properties
    ) {
        variables.managerProperties = {};
        var args = arguments;
        args.keyArray()
            .filter( function( key ) {
                return !isNull( args[ key ] );
            } )
            .each( function( key ) {
                if ( isSimpleValue( args[ key ] ) ) {
                    variables[ key ] = args[ key ];
                } else if ( key == "properties" ) {
                    variables.managerProperties = args[ key ];
                }
            } );

        if ( isSimpleValue( variables.seedEnvironments ) ) {
            variables.seedEnvironments = listToArray( variables.seedEnvironments );
        }

        return this;
    }

    function onDIComplete() {
        variables.manager = variables.wirebox.getInstance(
            name = variables.manager,
            initArguments = variables.managerProperties
        );
    }

    /**
     * Passes through to the manager's install method and runs all migrations if requested
     *
     * @runAll boolean  Whether to run all migrations after the managers install is performed
     */
    public void function install( runAll = false ) {
        variables.manager.install();

        if ( runAll ) {
            runAllMigrations( "up" );
        }
    }

    /**
     * Runs all migrations down and requests an uninstall from the manager
     */
    public void function uninstall() {
        if ( !variables.manager.isReady() ) {
            return;
        }

        runAllMigrations( "down" );

        variables.manager.uninstall();
    }

    /**
     * Resets the migrations to a new state
     */
    public void function reset() {
        return variables.manager.reset();
    }

    /**
     * Runs a single or group of migrations up
     *
     * @once  boolean When true, this will only run the first migration
     * @postProcessHook closure A closure which is run by the manager before the migration is performed. Defaults to an empty function.
     * @preProcessHook closure A closure which is run by the manager after the migration is performed. Defaults to an empty function.
     * @seed bolean Whether to run the seeders after migrations are performed
     */
    public MigrationService function up(
        boolean once = false,
        function postProcessHook = function() {
        },
        function preProcessHook = function() {
        },
        boolean seed = false
    ) {
        arguments.direction = "up";

        if ( arguments.once ) {
            runNextMigration( argumentCollection = arguments );
        } else {
            runAllMigrations( argumentCollection = arguments );
        }

        if ( arguments.seed ) {
            this.seed();
        }

        return this;
    }

    /**
     * Runs a single or group of migrations up
     *
     * @once  boolean When true, this will only run the first migration found
     * @postProcessHook closure A closure which is run by the manager before the migration is performed. Defaults to an empty function.
     * @preProcessHook closure A closure which is run by the manager after the migration is performed. Defaults to an empty function.
     */
    public MigrationService function down(
        boolean once = false,
        function postProcessHook = function() {
        },
        function preProcessHook = function() {
        }
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
     * Runs all or a single seed
     *
     * @seedName string when provided, only this seed will be run
     */
    public MigrationService function seed( string seedName ) {
        if ( !isNull( variables.environment ) && !variables.seedEnvironments.containsNoCase( variables.environment ) ) {
            throw(
                "You have attempted to run seeds in an unauthorized environment ( #variables.environment# ). Authorized environments are #variables.seedEnvironments.toList()#"
            );
        }

        if ( !directoryExists( expandPath( variables.seedsDirectory ) ) ) return this;

        findSeeds( argumentCollection = arguments ).each( function( file ) {
            variables.manager.runSeed( file.componentPath );
        } );

        return this;
    }

    /**
     * Run the next available migration in the desired direction.
     *
     * @direction The direction in which to look for the next available migration — `up` or `down`.
     * @postProcessHook  A callback to run after running each migration. Defaults to an empty function.
     * @preProcessHook  A callback to run before running each migration. Defaults to an empty function.
     *
     * @return    The ran migration information struct
     */
    public struct function runNextMigration(
        required string direction,
        function postProcessHook = function() {
        },
        function preProcessHook = function() {
        }
    ) {
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
     * @postProcessHook  A callback to run after running each migration. Defaults to an empty function.
     * @preProcessHook  A callback to run before running each migration. Defaults to an empty function.
     *
     * @return    void
     */
    public void function runAllMigrations(
        required string direction,
        function postProcessHook = function() {
        },
        function preProcessHook = function() {
        }
    ) {
        install();

        var migrations = arrayFilter( findAll(), function( migration ) {
            return direction == "up" ? !migration.migrated : migration.migrated;
        } );

        if ( arguments.direction == "down" ) {
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

    /**
     * Returns all available migrations within a director
     *
     * @directory string the directory to list
     */
    public array function findAll( string directory = variables.migrationsDirectory ) {
        var migrationFiles = directoryList(
            expandPath( arguments.directory ),
            false,
            "query",
            "*.cfc",
            "name",
            "file"
        ).reduce( function( result, row ) {
                result.append( row );
                return result;
            }, [] )
            .filter( function( item ) {
                return isMigrationFile( item.name );
            } );

        var processed = variables.manager.findProcessed();

        var prequisitesInstalled = true;
        var managerIsReady = variables.manager.isReady();

        var migrations = migrationFiles.map( function( file ) {
            var timestamp = extractTimestampFromFileName( file.name );
            var componentName = left( file.name, len( file.name ) - 4 );
            var migrationRan = managerIsReady ? processed.contains( componentName ) : false;

            var migration = {
                fileName: file.name,
                componentName: componentName,
                absolutePath: file.directory & "/" & file.name,
                componentPath: listChangeDelims(
                    directory & "/" & componentName,
                    ".",
                    "/",
                    false
                ),
                timestamp: timestamp,
                migrated: migrationRan,
                canMigrateUp: !migrationRan && prequisitesInstalled,
                canMigrateDown: migrationRan,
                migratedDate: ""
            };

            prequisitesInstalled = migrationRan;

            return migration;
        } );



        if ( !managerIsReady ) {
            arrayEach( migrations, function( migration ) {
                migration.canMigrateUp = false;
                migration.canMigrateDown = false;
            } );

            // sort in the correct order
            arraySort( migrations, function( a, b ) {
                return dateCompare( a.timestamp, b.timestamp );
            } );

            return migrations;
        }

        // sort in reversed order to get which migrations can be brought down
        migrations.sort( function( a, b ) {
            return dateCompare( b.timestamp, a.timestamp );
        } );

        var laterMigrationsNotInstalled = true;

        migrations.each( function( migration ) {
            migration.canMigrateDown = migration.migrated && laterMigrationsNotInstalled;
            laterMigrationsNotInstalled = !migration.migrated;
        } );

        // resort to timestamp asc
        migrations.sort( function( a, b ) {
            return dateCompare( a.timestamp, b.timestamp );
        } );

        return migrations;
    }

    /**
     * Finds all seeds
     *
     * @seedName  when provided, only seeds matching this name will be returned
     */
    public array function findSeeds( string seedName ) {
        return directoryList(
            expandPath( variables.seedsDirectory ),
            false,
            "query",
            arguments.keyExists( "seedName" ) ? arguments.seedName & ".cfc" : "*.cfc",
            "name",
            "file"
        ).reduce( function( result, row ) {
                result.append( row );
                return result;
            }, [] )
            .map( function( file ) {
                var componentName = left( file.name, len( file.name ) - 4 );
                structAppend(
                    file,
                    {
                        "componentName": componentName,
                        "componentPath": listChangeDelims(
                            variables.seedsDirectory & "/" & componentName,
                            ".",
                            "/",
                            false
                        )
                    }
                );
                return file;
            } )
    }

    /**
     * Determines whether there are migratiosn which need to be run
     *
     * @direction string  whether to filter for up or down migrations
     */
    public boolean function hasMigrationsToRun( direction ) {
        return !!findAll()
            .filter( function( migration ) {
                return direction == "up" ? !migration.migrated : migration.migrated;
            } )
            .len();
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
        postProcessHook = function() {
        },
        preProcessHook = function() {
        }
    ) {
        install();

        var migrationRan = isMigrationRan( migrationStruct.componentName );

        if ( migrationRan && direction == "up" ) {
            throw( "Cannot run a migration that has already been ran." );
        }

        if ( !migrationRan && direction == "down" ) {
            throw( "Cannot rollback a migration if it hasn't been ran yet." );
        }

        variables.manager.runMigration( argumentCollection = arguments );
    }

    /**
     * Determines whether a migration has been run
     *
     * @componentName The component to inspect
     */
    private boolean function isMigrationRan( componentName ) {
        return variables.manager.isMigrationRan( argumentCollection = arguments );
    }


    /**
     * Determines whether the file is a valid migration file
     *
     * @fileName string the name of the file to test
     */
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

    /**
     * Extracts the timestamp from the filename
     *
     * @fileName  The file name to extract from
     */
    private any function extractTimestampFromFileName( fileName ) {
        var timestampString = left( fileName, 17 );
        var timestampParts = listToArray( timestampString, "_" );
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
