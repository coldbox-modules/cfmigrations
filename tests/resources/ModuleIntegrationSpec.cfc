component extends="coldbox.system.testing.BaseTestCase" appMapping="/app"{

	function beforeAll() {
		super.beforeAll()
		getController().getModuleService().registerAndActivateModule( "cfmigrations", "testingModuleRoot" )
        // We do this here, because we manually load the module.
        getWireBox().autowire( this )
	}

	/**
	 * @beforeEach
	 */
	function setupIntegrationTest() {
		setup()
	}

	/**
	 * @aroundEach
	 */
	function useDatabaseTransactions( spec ) {
		transaction action="begin" {
			try {
				arguments.spec.body();
			} catch ( any e ) {
				rethrow;
			} finally {
				transaction action="rollback";
			}
		}
	}

}
