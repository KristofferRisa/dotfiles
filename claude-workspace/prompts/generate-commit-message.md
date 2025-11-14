# Generate Commit Message

## Purpose
Generate clear, semantic commit messages following conventional commits format.

## Input
Git diff or description of changes

## Instructions
Analyze the changes and create a commit message with:

1. **Type** (choose most appropriate):
   - `feat`: New feature
   - `fix`: Bug fix
   - `docs`: Documentation only
   - `style`: Code style changes (formatting, missing semicolons, etc.)
   - `refactor`: Code change that neither fixes a bug nor adds a feature
   - `perf`: Performance improvement
   - `test`: Adding missing tests
   - `chore`: Changes to build process or auxiliary tools
   - `ci`: CI configuration changes

2. **Scope** (optional): Component or file affected

3. **Description**: Brief summary (50 chars or less)

4. **Body** (if needed): Detailed explanation of what and why

5. **Footer** (if applicable): Breaking changes or issue references

## Format
```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

## Examples
```
feat(auth): add JWT token validation

Implement middleware to validate JWT tokens for protected routes.
Uses jsonwebtoken library with RS256 algorithm.

Closes #123
```

```
fix(api): handle null response in user endpoint

Previously crashed when user not found. Now returns 404 with
appropriate error message.
```

```
docs(readme): update installation instructions
```

## Guidelines
- Use imperative mood: "add" not "added" or "adds"
- Don't capitalize first letter of description
- No period at end of description
- Body explains what and why, not how
- Reference issues in footer
