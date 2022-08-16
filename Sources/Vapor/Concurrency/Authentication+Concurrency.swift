#if canImport(_Concurrency)
import NIOCore

/// Helper for creating authentication middleware.
///
/// See `AsyncRequestAuthenticator` and `AsyncSessionAuthenticator` for more information.
///
/// This is an async version of `Authenticator`
public protocol AsyncAuthenticator: AsyncMiddleware { }

/// Help for creating authentication middleware based on `Request`.
///
/// `Authenticator`'s use the incoming request to check for authentication information.
/// If valid authentication credentials are present, the authenticated user is added to `req.auth`.
///
/// This is an async version of `RequestAuthenticator`
public protocol AsyncRequestAuthenticator: AsyncAuthenticator {
    func authenticate(request: Request) async throws
}

extension AsyncRequestAuthenticator {
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        try await self.authenticate(request: request)
        return try await next.respond(to: request)
    }
}

// MARK: Basic

/// Helper for creating authentication middleware using the Basic authorization header.
///
/// This is an async version of `BasicAuthenticator`
public protocol AsyncBasicAuthenticator: AsyncRequestAuthenticator {
    func authenticate(basic: BasicAuthorization, for request: Request) async throws
}

extension AsyncBasicAuthenticator {
    public func authenticate(request: Request) async throws {
        guard let basicAuthorization = request.headers.basicAuthorization else {
            return
        }
        return try await self.authenticate(basic: basicAuthorization, for: request)
    }
}

// MARK: Bearer

/// Helper for creating authentication middleware using the Bearer authorization header.
///
/// This is an async version of `BearerAuthenticator`
public protocol AsyncBearerAuthenticator: AsyncRequestAuthenticator {
    func authenticate(bearer: BearerAuthorization, for request: Request) async throws
}

extension AsyncBearerAuthenticator {
    public func authenticate(request: Request) async throws {
        guard let bearerAuthorization = request.headers.bearerAuthorization else {
            return
        }
        return try await self.authenticate(bearer: bearerAuthorization, for: request)
    }
}

// MARK: Credentials

/// Helper for creating authentication middleware using request body contents.
///
/// This is an async version of `CredentialsAuthenticator`
public protocol AsyncCredentialsAuthenticator: AsyncRequestAuthenticator {
    associatedtype Credentials: Content
    func authenticate(credentials: Credentials, for request: Request) async throws
}

extension AsyncCredentialsAuthenticator {
    public func authenticate(request: Request) async throws {
        let credentials: Credentials
        do {
            credentials = try request.content.decode(Credentials.self)
        } catch {
            return
        }
        return try await self.authenticate(credentials: credentials, for: request)
    }
}

/// Helper for creating authentication middleware in conjunction with `SessionsMiddleware`.
///
/// This is an async version of `SessionAuthenticator`
public protocol AsyncSessionAuthenticator: AsyncAuthenticator {
    associatedtype User: SessionAuthenticatable

    /// Authenticate a model with the supplied ID.
    func authenticate(sessionID: User.SessionID, for request: Request) async throws
}

extension AsyncSessionAuthenticator {
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // if the user has already been authenticated
        // by a previous middleware, continue
        if await request.auth.asyncHas(User.self) {
            return try await next.respond(to: request)
        }

        if let aID = await request.asyncSession.authenticated(User.self) {
            // try to find user with id from session
            try await self.authenticate(sessionID: aID, for: request)
        }
        
        // respond to the request
        let response = try await next.respond(to: request)
        if let user = await request.auth.asyncGet(User.self) {
            // if a user has been authed (or is still authed), store in the session
            await request.asyncSession.authenticate(user)
        } else if await request.hasAsyncSession {
            // if no user is authed, it's possible they've been unauthed.
            // remove from session.
            await request.asyncSession.unauthenticate(User.self)
        }
        return response
    }
}

/// Models conforming to this protocol can have their authentication
/// status cached using `AsyncSessionAuthenticator`.
/// `async` version of `SessionAuthenticatable`
public protocol AsyncSessionAuthenticatable: Authenticatable {
    /// Session identifier type.
    associatedtype SessionID: LosslessStringConvertible

    /// Unique session identifier.
    var sessionID: SessionID { get }
}

private extension AsyncSessionAuthenticatable {
    static var sessionName: String {
        return "\(Self.self)"
    }
}

#endif
