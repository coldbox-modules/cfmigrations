component {

	function run( qb, mockData ) {
	
		var testUsers = mockData.mock(
			argumentCollection = {
				"$num"     : 20,
				"email"    : "email",
				"password" : "word"
			}
		);

		qb.table( "users" ).insert( testUsers );
	}

}
