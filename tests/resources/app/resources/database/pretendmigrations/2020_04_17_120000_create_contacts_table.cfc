component {

    function up( schema, query ) {
        queryExecute(
            "CREATE TABLE contacts (
                id INTEGER NOT NULL,
                name VARCHAR(100) NOT NULL,
                email VARCHAR(255) NOT NULL
            )",
            {},
            { datasource: "cfmigrations_testing" }
        );
    }

    function down( schema, query ) {
        queryExecute(
            "DROP TABLE contacts",
            {},
            { datasource: "cfmigrations_testing" }
        );
    }

}
