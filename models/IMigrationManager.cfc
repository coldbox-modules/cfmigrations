interface {

    public boolean function isReady();

    /**
     * Performs the necessary routines to setup the migration manager for operation
     */
    public void function install();

    /**
     * Uninstalls the migrations schema
     */
    public void function uninstall();

    /**
     * Resets the database to an empty state
     */
    public void function reset();

    /**
     * Finds all processed migrations
     */
    array function findProcessed();


    /**
     * Determines whether a migration has been run
     *
     * @componentName The component to inspect
     */
    boolean function isMigrationRan( string componentName );

    /**
     * Logs a migration as completed
     *
     * @direction  Whether to log it as up or down
     * @componentName The component name to log
     */
    private void function logMigration( string direction, string componentName );


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
        function postProcessHook,
        function preProcessHook
    );

    /**
     * Runs a single seed
     *
     * @invocationPath the component invocation path for the seed
     */
    public void function runSeed(
        required string invocationPath,
        function postProcessHook,
        function preProcessHook
    );

}
