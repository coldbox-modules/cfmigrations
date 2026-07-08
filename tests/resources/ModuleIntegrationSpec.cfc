component extends="coldbox.system.testing.BaseTestCase" autowire="true" appMapping="/app"{

	function beforeAll() {
		super.beforeAll();
		getController().getModuleService().registerAndActivateModule( "cfmigrations", "testingModuleRoot" );
	}

	/**
	 * @beforeEach
	 */
	function setupIntegrationTest() {
		setup();
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
