component {

	function run( schema, query, mockData ) {
	
		var testUsers = mockData.mock(
			argumentCollection = {
				"$num"     : 20,
				"email"    : "email",
				"password" : "word"
			}
		);

		query.table( "users" ).insert( testUsers );
	}

}
