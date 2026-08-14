# Interface Design

Use interfaces to express behavior required at a boundary. Do not introduce one
only to follow a slogan or to make every concrete type mockable.

## Default: Define the Interface Near Its Consumer

Go's implicit interface satisfaction lets a consumer describe only the methods
it needs without changing the producer. This usually gives the interface a
clear purpose, keeps it narrow, and prevents one producer abstraction from
forcing unrelated consumers to depend on extra methods.

Apply this default when:

- a function needs interchangeable behavior;
- different consumers need different subsets of a concrete type's methods;
- a test double represents a real consumer boundary; or
- the abstraction is meaningful in the consumer's domain.

Do not create a consumer interface before there is a consumer that needs
substitution. A concrete parameter is simpler when the caller always needs that
specific type.

Keep an interface as small as its contract permits. One-method interfaces are
powerful because many types can satisfy them, but two methods is not a maximum.
A cohesive multi-method protocol is better than several interfaces that cannot
be used independently.

## Return Concrete Types by Default

A producer normally returns a concrete type. Callers then retain the complete
API, and each consumer can define its own narrow interface if needed.

This is a default, not a type-system rule. An exported function may legally
return an unexported concrete type, although callers cannot name that type
directly. Decide whether that restriction creates an intentional API or an
awkward one.

Do not return an interface solely to hide methods or enable mocks. Return an
interface when the interface itself is the stable public contract.

## Valid Producer-Side Interfaces

A producer-side or shared interface can be appropriate in these cases.

### Multiple hidden implementations

A factory may choose among implementations while exposing one deliberate
contract. `crypto/aes.NewCipher` returning the shared `cipher.Block` interface
is the standard-library pattern. Multiple hidden implementations make the
interface useful, but the language does not technically require this return
type.

### Shared cross-package contract

Some contracts are intentionally shared by many producers and consumers, such
as `io.Reader`, `fmt.Stringer`, `hash.Hash`, and
`encoding.BinaryMarshaler`. These interfaces belong to the package that owns
the abstraction, not necessarily to one immediate consumer.

The packages that contain them are not all "interface-only" packages. Their
justification is the stable shared contract.

### Hidden implementation with no additional public API

If a concrete type exists only to implement a public interface and exposes no
additional useful methods, returning the interface can keep implementation
details private. `rand.NewSource` returning `rand.Source` is an example.

### Protocol or sum of implementations

An interface can be the domain object when callers are expected to provide or
switch implementations. The producer then owns the protocol and must document
its behavioral contract, concurrency expectations, and lifecycle.

## Testing

Do not add a broad producer interface "for mocking." Test a producer through
its concrete public API. When another package needs a substitute, define the
narrow interface at that consumer boundary.

This is not an absolute ban on producer-owned fakes. A shared protocol may
provide a test implementation when consistent conformance testing or a complex
contract makes that useful. The test API must still represent production
behavior rather than expose implementation details.

## Decision Guide

<!-- markdownlint-disable MD013 -->
| Situation | Likely design |
| --- | --- |
| No behavioral substitution is needed | Use the concrete type |
| One consumer needs a subset of methods | Define a narrow consumer interface |
| Consumers need different method subsets | Define separate consumer interfaces |
| A factory exposes interchangeable hidden implementations | Consider a producer or shared interface |
| Many packages implement and consume one stable protocol | Put the interface with the shared abstraction |
| The implementation has useful additional methods | Return the concrete type by default |
| The only reason is mocking | Re-evaluate the consumer boundary |
| The interface methods are not cohesive | Split by independently useful behavior |
<!-- markdownlint-enable MD013 -->

## Review Questions

1. Which consumer requires substitution?
2. Could a concrete parameter express the requirement more directly?
3. Are all interface methods required together?
4. Does the interface expose behavior rather than data plumbing?
5. Who owns the contract: one consumer, a shared domain, or the producer?
6. Will returning an interface hide useful capabilities or lock the API into an
   abstraction prematurely?
7. Are cancellation, concurrency, ownership, and cleanup requirements clear?

## Official Sources

- [Go Wiki: Code Review Comments — Interfaces](https://go.dev/wiki/CodeReviewComments#interfaces)
- [Effective Go — Generality](https://go.dev/doc/effective_go#generality)
- [Go specification — Interface types](https://go.dev/ref/spec#Interface_types)
