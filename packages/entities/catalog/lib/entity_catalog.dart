/// API publique de entity_catalog : le contrat du catalogue fermé et son
/// validateur.
library;

export 'src/genesis_contract.dart' show GenesisContract;
export 'src/genesis_message_validator.dart' show GenesisMessageValidator;
export 'src/validated_envelope.dart'
    show
        ValidatedEnvelope,
        ValidationAccepted,
        ValidationCodes,
        ValidationIgnored,
        ValidationRejected,
        ValidationVerdict;
