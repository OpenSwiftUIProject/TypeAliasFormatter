import ProjectDescription

let tuist = Tuist(project: .tuist(generationOptions: .options(
    buildInsightsDisabled: true,
    testInsightsDisabled: true,
    includeGenerateScheme: false
)))
