/// go_router configuration (placeholder).
///
/// Routes (from PRD): login, password recovery, profile, settings, plants, process view,
/// equipment, alarms, trends, commands, setpoints, maintenance, shift handover, simulation.
/// Navigation adapts to user role (operator, engineer, supervisor, maintenance); on mobile
/// use tabs for plant, alarms, assets and more.
///
/// Security: role-based route guards are UX only - the API and Supabase RLS must enforce
/// authorization (skills/authorization/T17, T145).
