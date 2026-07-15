export const rooms = {
  area: (areaId: number) => `area:${areaId}`,
  courier: (courierId: number) => `courier:${courierId}`,
  areaVehicle: (areaId: number, vehicleId: number) =>
    `area:${areaId}:vehicle:${vehicleId}`,
  dashboard: () => `dashboard`,
  supplier: (userId: number) => `supplier:${userId}`,
  customer: (userId: number) => `customer:${userId}`,
} as const;
