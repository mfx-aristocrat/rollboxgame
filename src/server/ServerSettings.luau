-- Never enable persistence against an unverified/production experience for tests.
return table.freeze({
    persistenceEnabled = false,
    dataEnvironment = "test",
    testUniverseId = 0,
    productionUniverseId = 0,
    supporterPassId = 0, -- Proposed cosmetic pass: disabled until configuration/testing.
})
