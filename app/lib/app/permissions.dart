import '../models/models.dart';

/// UI mirror of api/src/auth/permissions.ts, used ONLY to adapt navigation and to explain why a
/// control is unavailable. It is never an enforcement point: the API re-checks role, plant
/// membership and interlocks on every request, and RLS guards direct database access (T17/T145).
enum UiAction { pumpToggle, valveToggle, modeSet, lockout, setpointPropose, setpointReview, alarmAcknowledge, maintenanceWrite, simulation }

const _matrix = <UiAction, Set<Role>>{
  UiAction.pumpToggle: {Role.operator, Role.supervisor},
  UiAction.valveToggle: {Role.operator, Role.supervisor},
  UiAction.modeSet: {Role.operator, Role.supervisor},
  UiAction.lockout: {Role.maintenance},
  UiAction.setpointPropose: {Role.engineer},
  UiAction.setpointReview: {Role.supervisor},
  UiAction.alarmAcknowledge: {Role.operator, Role.supervisor},
  UiAction.maintenanceWrite: {Role.maintenance},
  UiAction.simulation: {Role.supervisor},
};

bool uiAllows(Role? role, UiAction action) => role != null && (_matrix[action]?.contains(role) ?? false);

/// Plant sections and which roles see them in navigation.
enum PlantSection {
  process('Process', 'process'),
  alarms('Alarms', 'alarms'),
  equipment('Assets', 'equipment'),
  trends('Trends', 'trends'),
  commands('Commands', 'commands'),
  setpoints('Setpoints', 'setpoints'),
  maintenance('Maintenance', 'maintenance'),
  handover('Shift handover', 'handover');

  const PlantSection(this.label, this.path);
  final String label;
  final String path;

  String route(String plantId) => this == PlantSection.process ? '/plants/$plantId' : '/plants/$plantId/$path';
}

/// Role-adapted navigation (PRD: "Adapte a navegação aos perfis de usuário").
List<PlantSection> sectionsFor(Role? role) => switch (role) {
      Role.operator => const [PlantSection.process, PlantSection.alarms, PlantSection.equipment, PlantSection.commands, PlantSection.trends, PlantSection.setpoints, PlantSection.handover],
      Role.supervisor => PlantSection.values,
      Role.engineer => const [PlantSection.process, PlantSection.alarms, PlantSection.equipment, PlantSection.trends, PlantSection.setpoints, PlantSection.handover],
      Role.maintenance => const [PlantSection.process, PlantSection.alarms, PlantSection.equipment, PlantSection.maintenance, PlantSection.trends, PlantSection.handover],
      null => const [PlantSection.process],
    };
