namespace DonHang.Messaging;

// lesson: backend.l3.dead-letter-queue
// A poison message: one no delivery will ever handle, such as a body that is
// not the JSON the consumer expects, or a routing key it does not know. The
// consumer rejects it without requeueing, so RabbitMQ dead-letters it at
// once instead of handing it out again and again.
public sealed class PoisonMessageException(string message, Exception? inner = null) : Exception(message, inner);
