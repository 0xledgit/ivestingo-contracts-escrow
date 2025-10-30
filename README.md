# Sistema de Escrow con Aprobación Tácita para Servicios Profesionales

## 📋 Tabla de Contenidos

1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Innovación Tecnológica](#innovación-tecnológica)
3. [Arquitectura del Sistema](#arquitectura-del-sistema)
4. [Contratos Inteligentes](#contratos-inteligentes)
5. [Flujo de Uso Técnico](#flujo-de-uso-técnico)
6. [Ejemplos Prácticos](#ejemplos-prácticos)
7. [Ventajas de Negocio](#ventajas-de-negocio)
8. [Desarrollo y Testing](#desarrollo-y-testing)

---

## 🎯 Resumen Ejecutivo

Sistema de smart contracts para facilitar transacciones seguras entre Pymes y Expertos/Freelancers con:

- ✅ **Liberación progresiva por milestones** (hitos de trabajo)
- ✅ **Aprobación tácita automática** (timeout configurable, por defecto 8 días)
- ✅ **Protección para ambas partes** (Pyme puede rechazar entregas, Experto recibe pago garantizado)
- ✅ **Anticipo automático** al aceptar el contrato
- ✅ **Comisión de plataforma** cobrada una sola vez al inicio
- ✅ **Cancelación segura** antes de activación (reembolso 100%)
- ✅ **Transparencia total on-chain** con eventos auditables
- ✅ **Eficiencia de gas** mediante patrón Factory (EIP-1167 Clone)

### Características Clave

- **Patrón Factory**: Uso de EIP-1167 (Minimal Proxy/Clone) para eficiencia de gas (~90% de ahorro en deployment)
- **Proceso en dos pasos**: `initialize()` crea el escrow, `fund()` deposita fondos (soluciona problema de allowance)
- **Aprobación tácita**: Si la Pyme no revisa en `revisionPeriod` días, el milestone se aprueba automáticamente
- **Seguridad**: Separación de roles (Pyme, Experto, Admin) con control de acceso granular
- **Flexibilidad**: Período de revisión configurable por escrow

---

## �� Innovación Tecnológica

### Diferencias Clave con Sistemas Tradicionales de Escrow

| Aspecto | Escrow Tradicional | Sistema Blockchain Ivestingo |
|---------|-------------------|------------------------------|
| **Intermediario** | Tercero de confianza (banco, notario) | Smart contract (código auditable) |
| **Costo de intermediación** | 5-10% + fees fijos | 3-5% (configurable) |
| **Tiempo de liberación** | 3-7 días hábiles | Instantáneo (al aprobar/timeout) |
| **Transparencia** | Limitada, opaca | Total, todo on-chain verificable |
| **Aprobación tácita** | No existe | Automática tras período configurable |
| **Cancelación** | Requiere aprobación de ambas partes | Automática antes de activación |
| **Disputa** | Proceso legal costoso | Ciclo de rechazo/reentrega en contrato |
| **Auditoría** | Manual, costosa | Automática, on-chain |

### Optimización de Tiempos

```
PROCESO TRADICIONAL:
┌─────────────────────────────────────────────────────────────┐
│ Crear escrow (3 días) → Depósito (2 días) →               │
│ → Entrega (N días) → Revisión (7 días) →                  │
│ → Aprobación manual (3 días) → Liberación (5 días)        │
│ = 20+ días por milestone                                   │
└─────────────────────────────────────────────────────────────┘

PROCESO BLOCKCHAIN IVESTINGO:
┌─────────────────────────────────────────────────────────────┐
│ deployEscrow (1 tx, ~3 min) → fund (1 tx, ~3 min) →       │
│ → acceptContract (1 tx, anticipo liberado instantáneo) →   │
│ → deliverMilestone → aprobación tácita (8 días) o manual  │
│ = 8 días promedio por milestone (60% reducción)           │
└─────────────────────────────────────────────────────────────┘

⚡ REDUCCIÓN: 60% en tiempo promedio por milestone
```

### Flujo de Aprobación Inteligente

```
┌─────────────────────────────────────────────────────────────┐
│              MECANISMO DE APROBACIÓN TÁCITA                 │
└─────────────────────────────────────────────────────────────┘

Experto → deliverMilestone()
   │
   └─> timestamp capturado = block.timestamp
        │
        ├─> OPCIÓN 1: Pyme aprueba directamente
        │    └─> approveMilestone() → Liberación inmediata
        │
        ├─> OPCIÓN 2: Pyme rechaza
        │    └─> rejectMilestone() → Estado vuelve a InProgress
        │         └─> timestamp reiniciado a 0
        │              └─> Experto debe volver a entregar
        │
        └─> OPCIÓN 3: Pyme no actúa en revisionPeriod (8 días)
             └─> Cualquiera llama checkTacitApproval()
                  └─> Liberación automática

⚡ INNOVACIÓN: Protege al Experto de Pymes morosas sin quitar
               control de calidad a la Pyme
```

---

## 🏗️ Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────┐
│                     ARQUITECTURA TÉCNICA                     │
└─────────────────────────────────────────────────────────────┘

EscrowFactory (Fábrica de Escrows)
  │
  │ FUNCIÓN: deployEscrow(...)
  │ └─ Clona Escrow (EIP-1167 Clone, ahorro ~90% gas)
  │
  └──> Escrow #1 (Instancia única)
        │ - addressPyme: Wallet de la Pyme/Cliente
        │ - addressExpert: Wallet del Experto/Freelancer
        │ - addressAdmin: Admin de plataforma (recibe fees)
        │ - addressBaseToken: Token de pago (USDC/MockERC20)
        │
        ├─ Estado: Created → Funded → Active → Completed/Cancelled
        │
        ├─ Milestones:
        │   ├─ milestoneDescriptions[id] = descripción
        │   ├─ milestoneAmounts[id] = monto en baseToken
        │   ├─ milestoneStatuses[id] = InProgress/Delivered/Approved
        │   └─ milestoneDeliveryTimestamps[id] = timestamp de entrega
        │
        └─ Flujo:
             1. Pyme → deployEscrow() en Factory
             2. Pyme → approve() baseToken al Escrow clonado
             3. Pyme → fund() (deposita 100% de fondos)
             4. Experto → acceptContract() (recibe anticipo + activa)
             5. Loop por cada milestone:
                a. Experto → deliverMilestone()
                b. Pyme → approveMilestone() O rejectMilestone()
                   O Cualquiera → checkTacitApproval() (tras timeout)
             6. Último milestone aprobado → Estado Completed
```

### Estados del Escrow

```solidity
enum EscrowStatus {
    Created,     // Escrow creado, esperando fondos
    Funded,      // Fondos depositados, esperando aceptación del Experto
    Active,      // Experto aceptó, anticipo liberado, trabajando en milestones
    Completed,   // Todos los milestones aprobados
    Cancelled    // Cancelado por Pyme antes de Funded→Active
}
```

### Estados de Milestones

```solidity
enum MilestoneStatus {
    InProgress,  // Milestone en progreso (Experto trabajando)
    Delivered,   // Experto entregó, esperando revisión
    Approved     // Aprobado (directamente o por timeout), fondos liberados
}
```

---

## 📜 Contratos Inteligentes

### 1. EscrowFactory.sol

**Propósito**: Fábrica para desplegar escrows usando clonado (EIP-1167).

**Variables Inmutables**:
```solidity
address public immutable escrowImplementation;  // Implementación base de Escrow
```

**Variables de Estado**:
```solidity
address public admin;                          // Admin de la plataforma
address[] public escrows;                      // Todos los escrows desplegados
mapping(address => address[]) public pymeEscrows;    // Escrows por Pyme
mapping(address => address[]) public expertEscrows;  // Escrows por Experto
```

**Funciones Principales**:

#### `deployEscrow(...)`
Crea un nuevo escrow clonando la implementación.

**Parámetros**:
```solidity
function deployEscrow(
    address _addressPyme,                    // Wallet de la Pyme/Cliente
    address _addressBaseToken,               // Token de pago (USDC/MockERC20)
    address _addressExpert,                  // Wallet del Experto/Freelancer
    uint256 _totalMilestonesAmount,          // Monto total del contrato
    string[] memory _milestoneDescriptions,  // ["Diseño UI", "Backend API", ...]
    uint256[] memory _milestoneAmounts,      // [3000, 5000, 2000] en baseToken
    uint256 _revisionPeriod,                 // Período de revisión en segundos (ej: 691200 = 8 días)
    uint256 _platformFee                     // Fee en basis points (500 = 5%)
) external returns (address)
```

**Validaciones**:
- Arrays deben tener la misma longitud
- `sum(_milestoneAmounts) == _totalMilestonesAmount`

**Retorna**:
- `address`: Dirección del contrato Escrow clonado

**Eventos**:
```solidity
event EscrowDeployed(
    address indexed escrowAddress,
    address indexed pyme,
    address indexed expert,
    uint256 totalAmount
);
```

**Flujo interno**:
1. Clona `escrowImplementation` (EIP-1167)
2. Inicializa el clon con `Escrow.initialize(...)`
3. Registra en `escrows`, `pymeEscrows` y `expertEscrows`
4. Emite evento `EscrowDeployed`

#### Funciones de Consulta

```solidity
function getEscrows() external view returns (address[] memory);
function getPymeEscrows(address _pyme) external view returns (address[] memory);
function getExpertEscrows(address _expert) external view returns (address[] memory);
function getTotalEscrows() external view returns (uint256);
```

---

### 2. Escrow.sol

**Propósito**: Contrato individual que gestiona un escrow de servicios profesionales.

**Variables de Configuración**:
```solidity
EscrowStatus public status;
bool private initialized;
uint256 public totalMilestonesAmount;          // Monto total del contrato
uint256 public totalMilestones;                // Número de milestones
uint256 public currentMilestone;               // Milestone actual (siguiente a completar)
uint256 public revisionPeriod;                 // Período de revisión en segundos
uint256 public platformFee;                    // Fee en basis points (500 = 5%)
```

**Direcciones**:
```solidity
address public addressPyme;                    // Wallet de la Pyme/Cliente
address public addressExpert;                  // Wallet del Experto/Freelancer
address public addressAdmin;                   // Admin/Plataforma (recibe fees)
address public addressBaseToken;               // Token de pago (USDC/MockERC20)
```

**Tracking de Milestones**:
```solidity
mapping(uint256 => string) public milestoneDescriptions;
mapping(uint256 => uint256) public milestoneAmounts;
mapping(uint256 => MilestoneStatus) public milestoneStatuses;
mapping(uint256 => uint256) public milestoneDeliveryTimestamps;
```

#### Funciones Principales

##### `initialize(...)`
Inicializa una instancia clonada (llamada por `EscrowFactory`). **NO transfiere fondos**.

**Validaciones**:
- No puede ser inicializado dos veces
- Todas las direcciones deben ser válidas (≠ address(0))
- Arrays de milestones deben tener la misma longitud
- Al menos un milestone requerido
- `platformFee <= 10000` (100%)
- **CRÍTICO**: `sum(milestoneAmounts) == totalMilestonesAmount`

**Efectos**:
- Establece todas las variables de estado
- `addressAdmin = msg.sender` (Factory)
- Estado → `Created`
- Emite `EscrowCreated`

---

##### `fund()`
La Pyme deposita el 100% de los fondos en el escrow.

**Requisitos**:
- `msg.sender == addressPyme` (solo la Pyme)
- Estado `Created`
- Pyme debe haber aprobado `totalMilestonesAmount` de `baseToken` al contrato

**Efectos**:
1. Transfiere `totalMilestonesAmount` de `baseToken` al contrato
2. Estado → `Funded`
3. Emite `EscrowFunded`

**Eventos**:
```solidity
emit EscrowFunded(addressPyme, totalMilestonesAmount);
```

**Nota Importante**: Este paso separado soluciona el problema de allowance, ya que el Escrow clonado tiene una dirección que solo se conoce DESPUÉS de ser creado.

---

##### `acceptContract()`
El Experto acepta el contrato, activando el escrow y recibiendo el anticipo (milestone 0).

**Requisitos**:
- `msg.sender == addressExpert` (solo el Experto)
- Estado `Funded`

**Lógica de Pago**:

```solidity
// 1. Cobra comisión total de plataforma (UNA SOLA VEZ)
uint256 totalPlatformFee = (totalMilestonesAmount * platformFee) / 10000;
IERC20(addressBaseToken).transfer(addressAdmin, totalPlatformFee);

// 2. Libera anticipo (milestone 0) al Experto
//    NOTA: Ya se descontó la comisión total, aquí NO se descuenta de nuevo
uint256 milestone0Amount = milestoneAmounts[0];
IERC20(addressBaseToken).transfer(addressExpert, milestone0Amount);

// 3. Marca milestone 0 como Approved
milestoneStatuses[0] = MilestoneStatus.Approved;

// 4. Avanza al siguiente milestone (si hay más)
if (totalMilestones > 1) {
    currentMilestone = 1;
    status = EscrowStatus.Active;
} else {
    status = EscrowStatus.Completed;
}
```


**Eventos**:
```solidity
emit EscrowActivated(addressExpert, milestone0Amount, totalPlatformFee);
emit PaymentReleased(addressExpert, milestone0Amount);
emit MilestoneApproved(0, milestone0Amount, false);
```

---

##### `deliverMilestone()`
El Experto marca un milestone como entregado, capturando el timestamp.

**Requisitos**:
- `msg.sender == addressExpert` (solo el Experto)
- Estado `Active`
- `currentMilestone < totalMilestones`
- `milestoneStatuses[currentMilestone] == InProgress`

**Efectos**:
1. `milestoneStatuses[currentMilestone] = Delivered`
2. `milestoneDeliveryTimestamps[currentMilestone] = block.timestamp`
3. Emite `MilestoneDelivered`

**Eventos**:
```solidity
emit MilestoneDelivered(currentMilestone, block.timestamp);
```

**Nota**: A partir de este momento, la Pyme tiene `revisionPeriod` segundos para revisar antes de que se active la aprobación tácita.

---

##### `approveMilestone()`
La Pyme aprueba directamente un milestone, liberando fondos al Experto.

**Requisitos**:
- `msg.sender == addressPyme` (solo la Pyme)
- Estado `Active`
- `milestoneStatuses[currentMilestone] == Delivered`

**Efectos**:
- Llama internamente a `_releaseMilestonePayment(currentMilestone, false)`

---

##### `checkTacitApproval()`
Cualquiera puede llamar esta función para verificar si el período de revisión expiró y aprobar tácitamente.

**Requisitos**:
- Estado `Active`
- `milestoneStatuses[currentMilestone] == Delivered`
- `milestoneDeliveryTimestamps[currentMilestone] > 0`
- `block.timestamp >= deliveryTimestamp + revisionPeriod`

**Efectos**:
- Llama internamente a `_releaseMilestonePayment(currentMilestone, true)`

**Nota**: Esta función permite que el Experto (o cualquiera) fuerce la aprobación si la Pyme no revisa a tiempo.

---

##### `_releaseMilestonePayment(uint256 milestoneId, bool isTacit)` (Privada)
Función interna que libera fondos del milestone al Experto.

**Lógica**:
```solidity
uint256 milestoneAmount = milestoneAmounts[milestoneId];
uint256 proportionalFee = (milestoneAmount * platformFee) / 10000;
uint256 netPayment = milestoneAmount - proportionalFee;

IERC20(addressBaseToken).transfer(addressExpert, netPayment);

milestoneStatuses[milestoneId] = MilestoneStatus.Approved;

if (currentMilestone == totalMilestones - 1) {
    status = EscrowStatus.Completed;
} else {
    currentMilestone++;
}
```

**Eventos**:
```solidity
emit MilestoneApproved(milestoneId, netPayment, isTacit);
emit PaymentReleased(addressExpert, netPayment);
emit EscrowCompleted(); // Si es el último milestone
```

**Nota sobre comisión**: La comisión de plataforma se cobra una única vez al inicio del contrato. Los pagos posteriores de milestones no descuentan comisión adicional.

---

##### `rejectMilestone()`
La Pyme rechaza un milestone, devolviéndolo a estado `InProgress` y reiniciando el timestamp.

**Requisitos**:
- `msg.sender == addressPyme` (solo la Pyme)
- Estado `Active`
- `milestoneStatuses[currentMilestone] == Delivered`

**Efectos**:
1. `milestoneStatuses[currentMilestone] = InProgress`
2. `milestoneDeliveryTimestamps[currentMilestone] = 0` (reinicia contador)
3. Emite `MilestoneRejected`

**Eventos**:
```solidity
emit MilestoneRejected(currentMilestone);
```

**Nota**: El Experto debe volver a llamar `deliverMilestone()` después de corregir el trabajo.

---

##### `cancelContract()`
La Pyme cancela el contrato ANTES de que el Experto lo acepte, recibiendo reembolso completo.

**Requisitos**:
- `msg.sender == addressPyme` (solo la Pyme)
- Estado `Funded` (después de `fund()`, antes de `acceptContract()`)

**Efectos**:
1. Transfiere `totalMilestonesAmount` de vuelta a la Pyme
2. Estado → `Cancelled`
3. Emite `EscrowCancelled`

**Eventos**:
```solidity
emit EscrowCancelled(addressPyme, totalMilestonesAmount);
```

**Nota**: NO se cobra comisión en cancelaciones.

---

##### Funciones de Consulta

```solidity
function getMilestone(uint256 milestoneId) public view returns (Milestone memory);
function getEscrowStatus() public view returns (EscrowStatus);
```

**Struct Milestone**:
```solidity
struct Milestone {
    string description;
    uint256 amount;
    MilestoneStatus status;
    uint256 deliveryTimestamp;
}
```

---

### 3. EscrowInterface.sol

**Propósito**: Define la interfaz completa del sistema de escrow con eventos y structs.

**Eventos Principales**:
```solidity
event EscrowCreated(address indexed pyme, address indexed expert, uint256 totalAmount);
event EscrowFunded(address indexed pyme, uint256 amount);
event EscrowActivated(address indexed expert, uint256 advancePayment, uint256 platformFee);
event MilestoneDelivered(uint256 indexed milestoneId, uint256 timestamp);
event MilestoneApproved(uint256 indexed milestoneId, uint256 amount, bool tacit);
event MilestoneRejected(uint256 indexed milestoneId);
event PaymentReleased(address indexed expert, uint256 amount);
event EscrowCompleted();
event EscrowCancelled(address indexed pyme, uint256 refundAmount);
```

---

## 🔧 Flujo de Uso Técnico

### Flujo Completo: Desde Deployment hasta Finalización

```
┌────────────────────────────────────────────────────────────────┐
│ FASE 0: DEPLOYMENT INICIAL (Solo una vez por red)             │
└────────────────────────────────────────────────────────────────┘

1. Deploy MockERC20 (o usar USDC en mainnet):
   forge create src/mocks/MockERC20.sol:MockERC20

2. Deploy EscrowFactory:
   forge create src/EscrowFactory.sol:EscrowFactory

   Resultado:
   - escrowImplementation desplegado automáticamente
   - EscrowFactory listo para crear escrows

┌────────────────────────────────────────────────────────────────┐
│ FASE 1: CREACIÓN DE ESCROW (Por cada proyecto)                │
└────────────────────────────────────────────────────────────────┘

3. Pyme llama EscrowFactory.deployEscrow(...):

   cast send <FACTORY_ADDRESS> \
     "deployEscrow(address,address,address,uint256,string[],uint256[],uint256,uint256)" \
     0x4Ac2bb44F3a89B13A1E9ce30aBd919c40CbA4385 \  # addressPyme
     0x6F13F39ea6B665A3AfCD4d02Cf27D881932C7238 \  # addressBaseToken (MockERC20)
     0x05703526dB38D9b2C661c9807367C14EB98b6c54 \  # addressExpert
     20000000000000 \                               # totalMilestonesAmount (20,000)
     '["terminar app indahouse","terminar smart contracts"]' \ # milestoneDescriptions
     '[3000000000000,17000000000000]' \            # milestoneAmounts [3000, 17000]
     691200 \                                       # revisionPeriod (8 días en segundos)
     500 \                                          # platformFee (5%)
     --rpc-url https://rpc-amoy.polygon.technology/ \
     --private-key <PYME_PRIVATE_KEY>

   Resultado:
   - Escrow clonado en <ESCROW_ADDRESS>
   - currentMilestone = 0, status = Created

┌────────────────────────────────────────────────────────────────┐
│ FASE 2: FONDEO DEL ESCROW                                     │
└────────────────────────────────────────────────────────────────┘

4. Pyme aprueba tokens al Escrow clonado:

   cast send <MOCK_ERC20_ADDRESS> \
     "approve(address,uint256)" \
     <ESCROW_ADDRESS> \
     20000000000000 \                               # totalMilestonesAmount
     --rpc-url https://rpc-amoy.polygon.technology/ \
     --private-key <PYME_PRIVATE_KEY>

5. Pyme deposita fondos:

   cast send <ESCROW_ADDRESS> \
     "fund()" \
     --rpc-url https://rpc-amoy.polygon.technology/ \
     --private-key <PYME_PRIVATE_KEY>

   Efectos:
   - 20,000 tokens transferidos al Escrow
   - status → Funded
   - Evento EscrowFunded emitido

┌────────────────────────────────────────────────────────────────┐
│ FASE 3: ACTIVACIÓN POR EL EXPERTO                             │
└────────────────────────────────────────────────────────────────┘

6. Experto acepta el contrato:

   cast send <ESCROW_ADDRESS> \
     "acceptContract()" \
     --rpc-url https://rpc-amoy.polygon.technology/ \
     --private-key <EXPERT_PRIVATE_KEY>

   Efectos:
   - Comisión total: (20000 * 500) / 10000 = 1000 → Admin
   - Anticipo: 3000 → Experto (milestone 0)
   - milestoneStatuses[0] = Approved
   - currentMilestone = 1
   - status → Active
   - Eventos: EscrowActivated, PaymentReleased, MilestoneApproved

┌────────────────────────────────────────────────────────────────┐
│ FASE 4: CICLO DE MILESTONES                                   │
└────────────────────────────────────────────────────────────────┘

7. Experto entrega milestone 1:

   cast send <ESCROW_ADDRESS> \
     "deliverMilestone()" \
     --rpc-url https://rpc-amoy.polygon.technology/ \
     --private-key <EXPERT_PRIVATE_KEY>

   Efectos:
   - milestoneStatuses[1] = Delivered
   - milestoneDeliveryTimestamps[1] = block.timestamp (ej: 1735000000)
   - Evento MilestoneDelivered(1, 1735000000)

8. ESCENARIO A - Pyme aprueba directamente:

   cast send <ESCROW_ADDRESS> \
     "approveMilestone()" \
     --rpc-url https://rpc-amoy.polygon.technology/ \
     --private-key <PYME_PRIVATE_KEY>

   Efectos:
   - Pago: 17000 - (17000 * 500 / 10000) = 16150 → Experto
   - milestoneStatuses[1] = Approved
   - currentMilestone = 2 (== totalMilestones)
   - status → Completed
   - Eventos: MilestoneApproved(1, 16150, false), PaymentReleased, EscrowCompleted

9. ESCENARIO B - Pyme rechaza:

   cast send <ESCROW_ADDRESS> \
     "rejectMilestone()" \
     --rpc-url https://rpc-amoy.polygon.technology/ \
     --private-key <PYME_PRIVATE_KEY>

   Efectos:
   - milestoneStatuses[1] = InProgress
   - milestoneDeliveryTimestamps[1] = 0
   - Evento MilestoneRejected(1)
   - Experto debe volver al paso 7

10. ESCENARIO C - Aprobación tácita (timeout):

    Después de 8 días (691200 segundos), cualquiera puede llamar:

    cast send <ESCROW_ADDRESS> \
      "checkTacitApproval()" \
      --rpc-url https://rpc-amoy.polygon.technology/ \
      --private-key <ANY_PRIVATE_KEY>

    Validación interna:
    - block.timestamp >= 1735000000 + 691200 = 1735691200

    Efectos (iguales a ESCENARIO A, pero isTacit = true):
    - Pago: 16150 → Experto
    - status → Completed
    - Evento MilestoneApproved(1, 16150, true)

┌────────────────────────────────────────────────────────────────┐
│ FASE 5 (ALTERNATIVA): CANCELACIÓN ANTES DE ACTIVACIÓN         │
└────────────────────────────────────────────────────────────────┘

Si la Pyme cambia de opinión antes de que el Experto acepte:

11. Pyme cancela:

    cast send <ESCROW_ADDRESS> \
      "cancelContract()" \
      --rpc-url https://rpc-amoy.polygon.technology/ \
      --private-key <PYME_PRIVATE_KEY>

    Efectos:
    - 20,000 tokens → Pyme (reembolso completo)
    - status → Cancelled
    - Evento EscrowCancelled(pyme, 20000)
```

---

## 📊 Ejemplos Prácticos

### Contratos de Ejemplo (Testnet)

```
┌─────────────────────────────────────────────────────────────┐
│               DIRECCIONES DE EJEMPLO (Testnet)               │
└─────────────────────────────────────────────────────────────┘

Admin/Owner:
  0x05703526dB38D9b2C661c9807367C14EB98b6c54

Pyme (Cliente):
  0x4Ac2bb44F3a89B13A1E9ce30aBd919c40CbA4385

Experto (Freelancer):
  0x05703526dB38D9b2C661c9807367C14EB98b6c54

EscrowFactory:
  0x... (Desplegar usando forge create)

MockERC20:
  0x... (Desplegar usando forge create)

RPC URL:
  https://rpc-amoy.polygon.technology/

Block Explorer:
  https://amoy.polygonscan.com/
```

### Ejemplo Completo: Proyecto "App Indahouse"

**Contexto**:
- Pyme contrata Experto para dos milestones:
  1. Terminar app indahouse (anticipo): 3,000 tokens
  2. Terminar smart contracts: 17,000 tokens
- Total: 20,000 tokens
- Comisión: 5% (1,000 tokens)
- Período de revisión: 8 días

**Flujo**:

```bash
# 1. Deploy Factory y MockERC20
forge create src/EscrowFactory.sol:EscrowFactory --rpc-url <RPC> --private-key <KEY>
forge create src/mocks/MockERC20.sol:MockERC20 --rpc-url <RPC> --private-key <KEY>

# 2. Pyme mintea tokens (si MockERC20)
cast send <MOCK_ERC20> "mint(address,uint256)" <PYME_ADDRESS> 20000000000000 --rpc-url <RPC> --private-key <KEY>

# 3. Pyme crea escrow
cast send <FACTORY> "deployEscrow(...)" [parámetros del ejemplo anterior]
# → Resultado: ESCROW_ADDRESS = 0xABC...

# 4. Pyme aprueba y fondea
cast send <MOCK_ERC20> "approve(address,uint256)" 0xABC... 20000000000000 --rpc-url <RPC> --private-key <PYME_KEY>
cast send 0xABC... "fund()" --rpc-url <RPC> --private-key <PYME_KEY>

# 5. Experto acepta (recibe 3,000 de anticipo)
cast send 0xABC... "acceptContract()" --rpc-url <RPC> --private-key <EXPERT_KEY>

# Balance del Experto: 3,000 tokens
# Balance del Admin: 1,000 tokens (comisión)
# Balance del Escrow: 16,000 tokens (milestone 1 pendiente)

# 6. Experto entrega milestone 1
cast send 0xABC... "deliverMilestone()" --rpc-url <RPC> --private-key <EXPERT_KEY>

# 7a. Pyme aprueba (liberación inmediata)
cast send 0xABC... "approveMilestone()" --rpc-url <RPC> --private-key <PYME_KEY>

# Balance final del Experto:
#   - Anticipo: 3,000
#   - Milestone 1: 17,000
#   - TOTAL: 20,000 tokens (antes de comisión)

# Balance final del Admin: 1,000 tokens (comisión de plataforma - 5%)
# Balance final del Experto: 19,000 tokens (después de comisión)
# Balance final del Escrow: 0 tokens
# Total distribuido: 19,000 + 1,000 = 20,000 tokens ✓
```

---

## 💼 Ventajas de Negocio

### Para las Pymes

| Ventaja | Descripción | Impacto Cuantificado |
|---------|-------------|----------------------|
| **Protección contra incumplimiento** | Fondos bloqueados hasta aprobación | Riesgo de pérdida total eliminado |
| **Control de calidad** | Puede rechazar entregas deficientes | Poder de revisión ilimitado |
| **Aprobación tácita** | Protección contra Expertos morosos | No requiere acción si conforme |
| **Cancelación segura** | Antes de activación, reembolso 100% | Sin riesgo por cambio de planes |
| **Transparencia** | Todo on-chain, auditable | Confianza en el sistema |

### Para los Expertos/Freelancers

| Ventaja | Descripción | Impacto Cuantificado |
|---------|-------------|----------------------|
| **Anticipo garantizado** | Al aceptar, recibe milestone 0 | Liquidez inmediata |
| **Protección contra morosidad** | Aprobación tácita tras 8 días | Pago garantizado si entrega |
| **Transparencia de fondos** | Sabe que los fondos están bloqueados | Confianza en el pago |
| **Menos fricción** | No requiere perseguir pagos | Ahorro de tiempo y estrés |

### Para la Plataforma

| Ventaja | Descripción | Impacto Cuantificado |
|---------|-------------|----------------------|
| **Escalabilidad** | Factory pattern permite escrows ilimitados | 0 costo marginal |
| **Automatización** | Smart contracts ejecutan reglas | Sin staff operativo |
| **Eficiencia de gas** | EIP-1167 Clone ahorra ~90% | De ~$100 a ~$10 (mainnet) |
| **Comisión garantizada** | Cobrada al inicio | No requiere perseguir pagos |

### Comparación de Costos

**Ejemplo: Pyme contrata Experto por $10,000 con 3 milestones**

| Concepto | Escrow Tradicional | Sistema Blockchain | Ahorro |
|----------|-------------------|-------------------|--------|
| Fee de plataforma | 8% = $800 | 5% = $500 | **$300** |
| Tiempo de liberación | 5 días por milestone | Instantáneo | **15 días** |
| Costo de disputa | $500-$2000 | $0 (ciclo rechazo/reentrega) | **$500-$2000** |
| Transparencia | Opaca | Total | **Priceless** |

---

## 🧪 Desarrollo y Testing

### Foundry - Setup

Este proyecto usa [Foundry](https://book.getfoundry.sh/) para desarrollo y testing.

#### Instalación

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

#### Comandos Principales

```bash
# Compilar contratos
forge build

# Ejecutar tests
forge test

# Ejecutar tests con verbosidad
forge test -vvv

# Gas report
forge test --gas-report

# Coverage
forge coverage

# Formatear código
forge fmt

# Desplegar en local (Anvil)
anvil  # En terminal separado
forge script script/Deployment.s.sol:DeploymentScript --rpc-url http://localhost:8545 --broadcast

# Desplegar en testnet (Polygon Amoy)
forge script script/Deployment.s.sol:DeploymentScript \
  --rpc-url https://rpc-amoy.polygon.technology/ \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### Estructura de Archivos

```
ivestingo-contracts-escrow/
├── src/
│   ├── Escrow.sol                      # Contrato de escrow individual
│   ├── EscrowFactory.sol               # Fábrica de escrows (EIP-1167)
│   └── interfaces/
│       └── EscrowInterface.sol         # Interfaz con eventos y structs
├── test/
│   ├── Escrow.t.sol                    # Tests del contrato Escrow
│   ├── EscrowFactory.t.sol             # Tests de la fábrica
│   └── mocks/
│       └── MockERC20.sol               # Mock para testing
├── script/
│   └── Deployment.s.sol                # Script de deployment
├── foundry.toml                        # Configuración de Foundry
├── .data                               # Ejemplos de comandos cast
└── README.md                           # Esta documentación
```

### Suite de Tests

El proyecto incluye una suite completa de tests unitarios y de integración que cubren:

- Creación de escrow via Factory
- Fondeo del escrow
- Aceptación y liberación de anticipo
- Entrega de milestones con timestamp
- Aprobación directa de milestones
- Aprobación tácita tras timeout
- Rechazo y reinicio de milestones
- Cancelación antes de activación
- Flujos completos con múltiples milestones
- Control de acceso por rol
- Cálculo correcto de comisiones

---

## 🔐 Seguridad

### Roles y Permisos

| Rol | Permisos | Restricciones |
|-----|----------|---------------|
| **Pyme** | `fund()`, `approveMilestone()`, `rejectMilestone()`, `cancelContract()` | Solo antes/durante estados válidos |
| **Experto** | `acceptContract()`, `deliverMilestone()` | Solo durante estados válidos |
| **Admin** | Recibe comisión | Asignado en `initialize()` (Factory) |
| **Cualquiera** | `checkTacitApproval()`, `finalizeCampaign()` | Solo si se cumplen condiciones |

### Consideraciones de Seguridad

1. ✅ **Reentrancy**: Uso de `IERC20` para transferencias seguras
2. ✅ **Integer Overflow**: Solidity 0.8.30+ tiene protección automática
3. ✅ **Access Control**: Modificadores `require(msg.sender == ...)` en funciones sensibles
4. ✅ **Inicialización única**: Flag `initialized` previene reinicialización
5. ✅ **Validación de arrays**: `sum(milestoneAmounts) == totalMilestonesAmount`
6. ✅ **Comisión única**: La comisión de plataforma se cobra una sola vez al inicio del contrato

**Importante**: Estos contratos están en fase de desarrollo. Se recomienda realizar una auditoría de seguridad completa antes de usar en producción.

---

## 📝 Licencia

MIT License

---

## 🤝 Contribución

Para contribuir al proyecto:

1. Fork el repositorio
2. Crear branch: `git checkout -b feature/nueva-funcionalidad`
3. Commit cambios: `git commit -am 'Agrega nueva funcionalidad'`
4. Push: `git push origin feature/nueva-funcionalidad`
5. Crear Pull Request

### Estándares de Código

- Solidity: Seguir [Solidity Style Guide](https://docs.soliditylang.org/en/latest/style-guide.html)
- Comentarios: NatSpec para todas las funciones públicas/externas
- Tests: Cobertura mínima 80%
- Gas optimization: Usar `forge snapshot` para comparar antes/después

---

## 📞 Soporte

Para preguntas o soporte:
- Email: ivestingo@gmail.com
- GitHub Issues: [ivestingo-contracts-escrow/issues](https://github.com/0xledgit/ivestingo-contracts-escrow/issues)

---

## 📚 Referencias Técnicas

- [EIP-1167: Minimal Proxy Contract](https://eips.ethereum.org/EIPS/eip-1167)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Foundry Book](https://book.getfoundry.sh/)
- [Polygon Amoy Testnet](https://polygon.technology/blog/introducing-the-amoy-testnet-for-polygon-pos)

---

**Última actualización**: 2025-01-26
**Versión**: 1.0.0 (Beta)